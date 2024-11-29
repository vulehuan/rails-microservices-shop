class HomeController < ApplicationController
  def index
    @products = fetch_products
  end

  private

  def fetch_products
    cache_key = 'home.products'
    cached_products = Rails.cache.read(cache_key)
    return cached_products if cached_products

    response = HTTParty.get(
      "#{Rails.application.config.product_service_url}/api/v1/products?per_page=48",
      headers: {
        "Authorization" => "Bearer #{fetch_jwt_token}",
        "Content-Type" => "application/json"
      }
    )

    if response.success?
      products = response.parsed_response["data"]
      Rails.cache.write(cache_key, products, expires_in: 1.hour) if products.present?
      return products
    end

    flash[:alert] = "Can not fetch products: #{response.message}"
    []
  end
end
