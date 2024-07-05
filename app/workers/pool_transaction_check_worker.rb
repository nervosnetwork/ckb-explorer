# Check every pending transaction in the pool if rejected
class PoolTransactionCheckWorker
  include Sidekiq::Worker
  sidekiq_options retry: 0

  def perform
    pending_transactions = CkbTransaction.tx_pending.where("created_at < ?",
                                                           2.minutes.ago).limit(100)
    pending_transactions.each do |tx|
      response_string = CkbSync::Api.instance.directly_single_call_rpc method: "get_transaction",
                                                                       params: [tx.tx_hash]
      reason = response_string["result"]["tx_status"]

      if reason["status"] == "rejected"
        ApplicationRecord.transaction do
          tx.update! tx_status: "rejected"
          tx.create_reject_reason!(message: reason["reason"])
        end
      end

      if reason["status"] == "unknown"
        ApplicationRecord.transaction do
          tx.update! tx_status: "rejected"
          tx.create_reject_reason!(message: "unknown")
        end
      end

      if reason["status"] == "committed" && CkbTransaction.where(tx_hash: tx.tx_hash).count == 2 && CkbTransaction.where(tx_hash: tx.tx_hash, tx_status: :committed).exists?
        tx.destroy
      end
    end
  end
end
