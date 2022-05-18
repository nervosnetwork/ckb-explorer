require "test_helper"

module Api
  module V2
    class DasAccountsControllerTest < ActionDispatch::IntegrationTest
      def after_setup
        super
        SecureRandom.stubs(:uuid).returns("11111111-1111-1111-1111-111111111111")
      end
      test "should return corresponding address alias" do
        DasIndexerService.any_instance.stubs(:reverse_record).returns("test")
        
        post api_v2_das_accounts_url, params: {addresses: ["test"]}
        
        assert_response :success
        data = JSON.parse response.body
        assert_equal data["test"], "test"
      # rescue => e
      #   puts e.backtrace.join("\n")
      end
    end
  end
end
