require 'rails_helper'

RSpec.describe ApplicationController, type: :controller do
  # Create a test controller that inherits from ApplicationController
  controller do
    def trigger_standard_error
      raise StandardError, "Test error"
    end

    def trigger_access_denied
      raise CanCan::AccessDenied, "Access denied test"
    end
  end

  describe "error handling" do
    # Test StandardError handling
    describe "StandardError rescue" do
      before do
        # Stub Sentry to prevent actual error reporting during tests
        allow(Sentry).to receive(:capture_exception)

        # Create a mock logger that responds to all standard logger methods
        @mock_logger = double('Logger')
        allow(@mock_logger).to receive(:error)
        allow(@mock_logger).to receive(:info?)
        allow(controller).to receive(:logger).and_return(@mock_logger)
      end

      it "catches and handles StandardError" do
        # Override the routes to use the test controller's action
        routes.draw { get 'trigger_standard_error' => 'anonymous#trigger_standard_error' }

        # Temporarily change Rails environment to development for backtrace logging
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))

        get :trigger_standard_error

        # Check that Sentry captured the exception
        expect(Sentry).to have_received(:capture_exception).with(an_instance_of(StandardError))

        # Verify the response
        expect(response).to have_http_status(:internal_server_error)
        expect(JSON.parse(response.body)['error']).to eq("An unexpected error occurred")

        # Verify logging
        expect(@mock_logger).to have_received(:error).with("Error: Test error")
        expect(@mock_logger).to have_received(:error).with(a_string_starting_with("Backtrace:"))
      end
    end

    # Test CanCan::AccessDenied handling
    describe "CanCan::AccessDenied rescue" do
      before do
        # Stub Sentry to prevent actual error reporting during tests
        allow(Sentry).to receive(:capture_exception)

        # Create a mock logger that responds to all standard logger methods
        @mock_logger = double('Logger')
        allow(@mock_logger).to receive(:error)
        allow(@mock_logger).to receive(:info?)
        allow(controller).to receive(:logger).and_return(@mock_logger)
      end

      it "catches and handles CanCan::AccessDenied" do
        # Override the routes to use the test controller's action
        routes.draw { get 'trigger_access_denied' => 'anonymous#trigger_access_denied' }

        get :trigger_access_denied

        # Check that Sentry captured the exception
        expect(Sentry).to have_received(:capture_exception).with(an_instance_of(CanCan::AccessDenied))

        # Verify the response
        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)['error']).to eq("Access Denied")

        # Verify logging
        expect(@mock_logger).to have_received(:error).with("Error: Access denied test")
      end
    end
  end
end