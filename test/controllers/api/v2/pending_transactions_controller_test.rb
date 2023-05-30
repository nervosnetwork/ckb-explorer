require "test_helper"

module Api
  module V2
    class PendingTransactionsControllerTest < ActionDispatch::IntegrationTest
      def setup
        super
        create(:pending_transaction)
        create(:pending_transaction)
        create(:pending_transaction)
      end
      test "should get index " do
        get api_v2_pending_transactions_url
        assert_response :success
        body = JSON.parse response.body
        assert_equal 3, body["data"].size
        assert_equal 3, body["meta"]["total"]
        # assert_equal 400, body['data'][0]['capacity_of_inputs']
      end
      test "should get count" do
        get count_api_v2_pending_transactions_url
        assert_response :success
      end
    end
  end
end
