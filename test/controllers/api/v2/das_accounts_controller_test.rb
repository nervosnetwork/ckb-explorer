require "test_helper"

module Api
  module V2
    class DasAccountsControllerTest < ActionDispatch::IntegrationTest
      def after_setup
        super
        SecureRandom.stubs(:uuid).returns("11111111-1111-1111-1111-111111111111")
      end

      test "should return empty address alias for an invalid address" do
        post api_v2_das_accounts_url, params: { addresses: ["test"] }

        assert_response :success
        assert_equal json, {}
      end

      test "should return corresponding address alias" do
        DasIndexerService.any_instance.stubs(:reverse_record).returns("test")
        post api_v2_das_accounts_url, params: { addresses: ["ckt1qyqrdsefa43s6m882pcj53m4gdnj4k440axqswmu83"] }

        assert_response :success
        assert_equal json["ckt1qyqrdsefa43s6m882pcj53m4gdnj4k440axqswmu83"], "test"
      end
    end
  end
end
