require "test_helper"

class PoolTransactionUpdateRejectReasonWorkerTest < ActiveSupport::TestCase
  setup do
    CkbSync::Api.any_instance.stubs(:generate_json_rpc_id).returns(1)
  end
  test "should detect and mark failed tx from pending tx, for inputs" do
    Sidekiq::Testing.inline!
    rejected_tx_id = '0xed2049c21ffccfcd26281d60f8f77ff117adb9df9d3f8cbe5fe86e893c66d359'

    rejected_transaction_attibutes_hash = {
      id: 1,
      tx_status: "rejected",
      created_at: Time.current,
      updated_at: Time.current
    }

    VCR.use_cassette('get_rejected_transaction') do
      PoolTransactionUpdateRejectReasonWorker.perform_async rejected_tx_id, rejected_transaction_attibutes_hash
      pool_transaction_entry = PoolTransactionEntry.find 1

      assert_equal 'rejected', pool_transaction_entry.tx_status
      assert pool_transaction_entry.detailed_message.include?("Resolve failed Dead")
    end
  end
end
