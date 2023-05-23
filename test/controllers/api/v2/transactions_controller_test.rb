require "test_helper"

module Api
  module V2
    class TransactionsControllerTest < ActionDispatch::IntegrationTest
      setup do
      end

      test "should get details" do
        ckb_transaction = create :ckb_transaction, :with_multiple_inputs_and_outputs

        puts "== ckb_transaction: #{ckb_transaction.tx_hash}"
        valid_get details_api_v2_transaction_url(id: ckb_transaction.tx_hash)
        assert_response :success
        json = JSON.parse response.body
        puts "== json: "
        puts json.inspect
        assert_equal 30, json['data'].size
        assert_equal "-800000000.0", json['data'][0]['transfers'][0]['capacity']
        assert_equal 'ordinary_transfer', json['data'][0]['transfers'][0]['transfer_type']
      end

    end
  end
end
