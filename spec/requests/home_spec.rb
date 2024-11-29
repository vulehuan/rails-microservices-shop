require 'rails_helper'
require 'webmock/rspec'

RSpec.describe "HomeController", type: :request do
  let(:user_token) { jwt_token_for('user') }

  before do
    stub_request(:get, "#{Rails.application.config.product_service_url}/api/v1/products")
      .with(headers: {
        'Accept' => '*/*',
        'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
        'Authorization' => "Bearer #{user_token}",
        'Content-Type' => 'application/json',
        'User-Agent' => 'Ruby'
      })
      .to_return(
        status: 200,
        body: {
          data: [
            { id: 1, name: "Product 1", image: "https://picsum.photos/480/360?random=1", price: "100.0", stock_quantity: 10, status: true },
            { id: 2, name: "Product 2", image: "https://picsum.photos/480/360?random=2", price: "200.0", stock_quantity: 20, status: false },
          ]
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  it "renders the index template with products" do
    get '/'
    expect(response).to have_http_status(:ok)
    expect(assigns(:products)).not_to be_empty
    expect(assigns(:products).first["name"]).to eq("Product 1")
  end

  context "when the product service response is unsuccessful" do
    before do
      # Mock the HTTParty response to simulate failure
      allow(HTTParty).to receive(:get).and_return(
        double("HTTParty::Response", success?: false, message: "Service Unavailable")
      )
      get '/'
    end

    it "sets the flash alert with the error message" do
      expect(flash[:alert]).to eq("Can not fetch products: Service Unavailable")
    end

    it "assigns an empty @products" do
      expect(assigns(:products)).to eq([])
    end

    it "renders the index template" do
      expect(response).to render_template(:index)
    end
  end
end
