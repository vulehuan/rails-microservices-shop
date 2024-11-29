class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

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
