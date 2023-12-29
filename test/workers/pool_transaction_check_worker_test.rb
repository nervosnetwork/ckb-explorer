require "test_helper"

class PoolTransactionCheckWorkerTest < ActiveSupport::TestCase
  test "should marked tx to rejected when rpc returns rejected" do
    CkbSync::Api.any_instance.stubs(:generate_json_rpc_id).returns(1)
    rejected_tx_id = "0xed2049c21ffccfcd26281d60f8f77ff117adb9df9d3f8cbe5fe86e893c66d359"
    pending_tx = create(:pending_transaction,
                        tx_hash: rejected_tx_id, created_at: 10.minutes.ago)

    Sidekiq::Testing.inline!
    VCR.use_cassette("get_rejected_transaction") do
      PoolTransactionCheckWorker.perform_async
      assert_equal "rejected", pending_tx.reload.tx_status
      assert pending_tx.detailed_message.include?("Resolve failed Dead")
    end
  end

  test "should marked tx to rejected when rpc returns unknown" do
    CkbSync::Api.any_instance.stubs(:generate_json_rpc_id).returns(2)
    unknown_tx_id = "0x1cebe4b6ddae45264790835200fe3a4efdc58e3474e552aff2246eb42b79ed2c"
    pending_tx = create(:pending_transaction,
                        tx_hash: unknown_tx_id, created_at: 10.minutes.ago)

    Sidekiq::Testing.inline!
    VCR.use_cassette("get_rejected_transaction") do
      PoolTransactionCheckWorker.perform_async
      assert_equal "rejected", pending_tx.reload.tx_status
      assert pending_tx.detailed_message.include?("unknown")
    end
  end
end
