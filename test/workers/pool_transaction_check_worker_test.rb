require "test_helper"

class PoolTransactionCheckWorkerTest < ActiveSupport::TestCase
  setup do
    rejected_tx_id = "0xed2049c21ffccfcd26281d60f8f77ff117adb9df9d3f8cbe5fe86e893c66d359"
    @pending_tx = create(:pending_transaction,
                         tx_hash: rejected_tx_id, created_at: 10.minutes.ago)
  end

  test "should detect and mark failed tx from pending tx, for inputs" do
    Sidekiq::Testing.inline!
    VCR.use_cassette("get_rejected_transaction") do
      PoolTransactionCheckWorker.perform_async
      assert_equal "rejected", @pending_tx.reload.tx_status
      assert @pending_tx.detailed_message.include?("Resolve failed Dead")
    end
  end
end
