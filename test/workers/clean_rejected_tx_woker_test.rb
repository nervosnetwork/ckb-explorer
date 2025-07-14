require "test_helper"

class CleanRejectedTxWorkerTest < ActiveSupport::TestCase
  test "should clean rejected tx" do
    tx = create(:ckb_transaction, block: nil, created_at: 5.hours.ago, tx_status: "rejected")
    create(:cell_output, ckb_transaction: tx, status: "rejected", block: nil)

    Sidekiq::Testing.inline!
    assert_changes -> { CkbTransaction.count }, from: 1, to: 0 do
      CleanRejectedTxWorker.perform_async
    end
    assert_equal 0, CellOutput.count
    assert_equal 0, HeaderDependency.count
    assert_equal 0, Witness.count
  end
end
