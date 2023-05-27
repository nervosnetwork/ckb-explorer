require "test_helper"

class PoolTransactionUpdateRejectReasonWorkerTest < ActiveSupport::TestCase
  setup do
    CkbSync::Api.any_instance.stubs(:generate_json_rpc_id).returns(1)
  end
  test "should detect and mark failed tx from pending tx, for inputs" do
    Sidekiq::Testing.inline!
    rejected_tx_id = "0xed2049c21ffccfcd26281d60f8f77ff117adb9df9d3f8cbe5fe86e893c66d359"
    create :pending_transaction, tx_hash: rejected_tx_id
    VCR.use_cassette("get_rejected_transaction") do
      PoolTransactionUpdateRejectReasonWorker.perform_async rejected_tx_id
      pending_transaction = CkbTransaction.find_by tx_hash: rejected_tx_id

      assert_equal "rejected", pending_transaction.tx_status
      assert pending_transaction.detailed_message.include?("Resolve failed Dead")
    end
  end
end
