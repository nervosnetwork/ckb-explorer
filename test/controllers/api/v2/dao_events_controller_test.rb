require "test_helper"

module Api
  module V2
    class DaoEventsControllerTest < ActionDispatch::IntegrationTest
      def setup
        super
        @block = create(:block)
        @address = create(:address)
        @ckb_transaction = create(:ckb_transaction, block: @block)
        @dao_contract = create(:dao_contract)
        @amount = 10000
      end
      test "should get index, deposit_to_dao" do

        create(:dao_event_with_block, block_id: @block.id, contract_id: @dao_contract.id, address_id: @address.id,
                            ckb_transaction_id: @ckb_transaction.id,
                            event_type: :deposit_to_dao, value: @amount
              )
        get api_v2_dao_events_url, params: {address: @address.address_hash}

        assert_response :success
        data = JSON.parse response.body
        activity = data["data"]['attributes']['activities'].first
        assert_equal activity['type'], "deposit_to_dao"
        assert_equal activity['amount'], @amount.to_s
      end

      test "should get index" do

        create(:dao_event_with_block, block_id: @block.id, contract_id: @dao_contract.id, address_id: @address.id,
                            ckb_transaction_id: @ckb_transaction.id,
                            event_type: :withdraw_from_dao, value: @amount
              )
        get api_v2_dao_events_url, params: {address: @address.address_hash}

        assert_response :success
        data = JSON.parse response.body
        activity = data["data"]['attributes']['activities'].first
        assert_equal activity['type'], "withdraw_from_dao"
        assert_equal activity['amount'], @amount.to_s
      end
    end
  end
end
