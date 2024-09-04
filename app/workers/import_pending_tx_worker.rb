# Check every pending transaction in the pool if rejected
class ImportPendingTxWorker
  include Sidekiq::Worker
  sidekiq_options retry: 1, queue: "pending_tx"

  def perform(data)
    committed_tx = CkbTransaction.tx_committed.find_by(tx_hash: data["transaction"]["hash"])
    if committed_tx && committed_tx.confirmation_time.nil?
      confirmation_time = committed_tx.block_timestamp - data["timestamp"].hex
      committed_tx.update(confirmation_time:)
    else
      CkbSync::Transactions.new([data]).import
    end
  end
end
