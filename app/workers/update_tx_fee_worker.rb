class UpdateTxFeeWorker
  include Sidekiq::Worker
  sidekiq_options queue: "tx_fee_updater", lock: :until_executed

  def perform(block_id)
    block = Block.find(block_id)

    CkbSync::Persist.update_tx_fee_related_data(block)
  end
end
