require "test_helper"

module Api
  module V2
    class DasAccountsControllerTest < ActionDispatch::IntegrationTest
      test "should return corresponding address alias" do
        DasIndexerService.any_instance.stubs(:reverse_record).returns("test")
        post api_v2_das_accounts_url, params: {addresses: ["test"]}
        data = JSON.parse response.body
        assert_equal data["test"], "test"
      end
    end
  end
end
