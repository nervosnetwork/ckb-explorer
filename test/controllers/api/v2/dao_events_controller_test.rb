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

        @cell_output = create(:cell_output, ckb_transaction_id: @ckb_transaction.id, block_id: @block.id, 
                              cell_index: 1, tx_hash: @ckb_transaction.tx_hash
                             )
        @cell_input = create(:cell_input, ckb_transaction_id: @ckb_transaction.id, block_id: @block.id,
                             previous_output: { tx_hash: @ckb_transaction.tx_hash, index: 1,
                                                capacity: 1000,
                                                interest: 222 },
                            )

        @amount = 10000
      end
      test "should get index, deposit_to_dao" do

        create(:dao_event_with_block, block_id: @block.id, contract_id: @dao_contract.id, address_id: @address.id,
                            ckb_transaction_id: @ckb_transaction.id,
                            event_type: :deposit_to_dao, value: @amount
              )

        CkbTransaction.any_instance.stubs(:display_inputs).returns([{
          address_hash: @address.address_hash,
          capacity: 1000,
          interest: 222,
          cell_type: 'nervos_dao_deposit'
        }])
        CkbTransaction.any_instance.stubs(:display_outputs).returns([{
          capacity: 2000,
          address_hash: @address.address_hash
        }])

        get api_v2_dao_events_url, params: {address: @address.address_hash}

        assert_response :success
      end

      test "should get index with 'withdraw_from_dao'" do

        create(:dao_event_with_block, block_id: @block.id, contract_id: @dao_contract.id, address_id: @address.id,
                            ckb_transaction_id: @ckb_transaction.id,
                            event_type: :withdraw_from_dao, value: @amount
              )
        CkbTransaction.any_instance.stubs(:display_inputs).returns([{
          address_hash: @address.address_hash,
          capacity: 1000,
          interest: 222,
          cell_type: 'nervos_dao_withdrawing'
        }])
        CkbTransaction.any_instance.stubs(:display_outputs).returns([{
          capacity: 2000,
          address_hash: @address.address_hash
        }])

        get api_v2_dao_events_url, params: {address: @address.address_hash}

        assert_response :success
      end

      test "should get index with 'issue_interest'" do

        create(:dao_event_with_block, block_id: @block.id, contract_id: @dao_contract.id, address_id: @address.id,
                            ckb_transaction_id: @ckb_transaction.id,
                            event_type: :issue_interest, value: @amount
              )
        CkbTransaction.any_instance.stubs(:display_inputs).returns([{
          address_hash: @address.address_hash,
          capacity: 1000,
          interest: 222,
          cell_type: 'nervos_dao_withdrawing'
        }])
        CkbTransaction.any_instance.stubs(:display_outputs).returns([{
          capacity: 1222,
          address_hash: @address.address_hash
        }])

        get api_v2_dao_events_url, params: {address: @address.address_hash}
        assert_response :success
      end
    end
  end
end
