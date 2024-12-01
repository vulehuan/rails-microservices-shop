class ApplicationController < ActionController::Base
  before_action :load_categories

  rescue_from StandardError, with: :handle_error
  rescue_from CanCan::AccessDenied, with: :access_denied

  def fetch_jwt_token(role = 'user', user_id = nil)
    payload = {
      role: role,
      exp: 15.minutes.from_now.to_i
    }
    payload[:user_id] = user_id if user_id

    secret_key = ENV.fetch('JWT_KEY', 'default_secret')
    JWT.encode(payload, secret_key, 'HS256')
  end

  private

  def load_categories
    cache_key = 'categories'
    cached_categories = Rails.cache.read(cache_key)
    @categories = cached_categories and return if cached_categories

    response = HTTParty.get(
      "#{Rails.application.config.product_service_url}/api/v1/categories?per_page=48",
      headers: {
        "Authorization" => "Bearer #{fetch_jwt_token}",
        "Content-Type" => "application/json"
      }
    )
    if response.success?
      @categories = response.parsed_response['data']
      Rails.cache.write(cache_key, @categories, expires_in: 1.hour) if @categories.present?
    else
      @categories = []
      Rails.logger.error("Failed to fetch categories: #{response.message}")
    end
  end

  def handle_error(exception)
    # SendErrorToSentryJob.perform_later(exception)
    Sentry.capture_exception(exception)
    logger.error "Error: #{exception.message}"
    logger.error "Backtrace: #{exception.backtrace.join("\n")}" if Rails.env.development? || Rails.env.test?

    render json: { error: "An unexpected error occurred" }, status: :internal_server_error
  end

  def access_denied(exception)
    Sentry.capture_exception(exception)
    logger.error "Error: #{exception.message}"

    render json: { error: "Access Denied" }, status: :forbidden
  end
end
