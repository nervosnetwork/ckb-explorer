# 1.Check every pending transaction in the pool if rejected
# 2.When a pending tx import to db and the same tx was import by node processor,it will exist two same tx with different status
class CleanRejectedTxWorker
  include Sidekiq::Worker
  sidekiq_options retry: 0

  def perform
    rejected_tx_ids = CkbTransaction.tx_rejected.where("created_at < ?", 4.hours.ago).limit(100).pluck(:id)
    rejected_output_ids = CellOutput.rejected.where(ckb_transaction_id: rejected_tx_ids).pluck(:id)
    CellDatum.where(cell_output_id: rejected_output_ids).delete_all
    CellOutput.where(id: rejected_output_ids).delete_all
    CellInput.where(ckb_transaction_id: rejected_tx_ids).delete_all
    AccountBook.where(ckb_transaction_id: rejected_tx_ids).delete_all
    CellDependency.where(ckb_transaction_id: rejected_tx_ids).delete_all
    Witness.where(ckb_transaction_id: rejected_tx_ids).delete_all
    HeaderDependency.where(ckb_transaction_id: rejected_tx_ids).delete_all
    RejectReason.where(ckb_transaction_id: rejected_tx_ids).delete_all
    CkbTransaction.where(id: rejected_tx_ids).delete_all
  end
end
