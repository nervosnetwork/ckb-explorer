# Check every pending transaction in the pool if rejected
class ImportPendingTxWorker
  include Sidekiq::Worker
  sidekiq_options retry: 0, queue: "pending_tx"

  def perform(data)
    if CkbTransaction.tx_committed.find_by(tx_hash: data["transaction"]["hash"])
    else
      CkbSync::Transactions.new([data]).import
    end
  end
end
