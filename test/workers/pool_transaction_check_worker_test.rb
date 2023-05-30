require "test_helper"

class PoolTransactionCheckWorkerTest < ActiveSupport::TestCase
  setup do
    CkbSync::Api.any_instance.stubs(:generate_json_rpc_id).returns(1)
    Sidekiq::Testing.inline!
  end
  test "should detect and mark failed tx from pending tx, for inputs" do
    rejected_tx_id = "0xed2049c21ffccfcd26281d60f8f77ff117adb9df9d3f8cbe5fe86e893c66d359"

    block = create(:block)

    cell_output = create(:cell_output,
                         :with_full_transaction,
                         block: block,
                         ckb_transaction_id: rejected_tx_id)
    cell_output.update tx_hash: rejected_tx_id, cell_index: 0, status: "dead"
    tx = create :pending_transaction, tx_hash: rejected_tx_id
    tx.cell_inputs.create previous_tx_hash: rejected_tx_id, previous_index: 0

    VCR.use_cassette("get_rejected_transaction") do
      PoolTransactionCheckWorker.perform_inline
      PoolTransactionUpdateRejectReasonWorker.perform_async rejected_tx_id
      pending_transaction = CkbTransaction.find_by(tx_hash: rejected_tx_id)

      assert_equal "rejected", pending_transaction.tx_status
      assert pending_transaction.detailed_message.include?("Resolve failed Dead")
    end
  end

  test "should detect and mark failed tx from pending tx, for cell_deps" do
    rejected_tx_id = "0xed2049c21ffccfcd26281d60f8f77ff117adb9df9d3f8cbe5fe86e893c66d359"
    script = create :script
    block = create(:block)
    cell_output = create(:cell_output, :with_full_transaction, block: block,
                                                               ckb_transaction_id: rejected_tx_id)
    cell_output.update tx_hash: rejected_tx_id, cell_index: 0, status: "dead"

    tx = create :pending_transaction, tx_hash: rejected_tx_id
    tx.cell_dependencies.create(dep_type: :code, cell_output: cell_output, script: script)

    VCR.use_cassette("get_rejected_transaction") do
      PoolTransactionUpdateRejectReasonWorker.perform_inline rejected_tx_id

      pending_transaction = CkbTransaction.find_by(tx_hash: rejected_tx_id)
      assert_equal "rejected", pending_transaction.tx_status
      assert pending_transaction.detailed_message.include?("Resolve failed Dead")
    end
  end
end
