class RemoveTxDisplayInfoWorker
  include Sidekiq::Worker

  def perform(block_id)
    tx_ids = CellOutput.where(id: CellInput.where(block_id: block_id).pluck(:previous_cell_output_id)).pluck(:ckb_transaction_id)
    TxDisplayInfo.where(ckb_transaction_id: tx_ids).delete_all
  end
end
