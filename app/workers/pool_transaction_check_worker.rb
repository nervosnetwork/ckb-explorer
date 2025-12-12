# 1. Check every pending transaction in the pool if rejected
# 2. When a pending tx is imported to db and the same tx was imported by node processor, it will exist two same tx with different status
class PoolTransactionCheckWorker
  include Sidekiq::Worker
  sidekiq_options retry: 0

  def perform
    pending_transactions = CkbTransaction.tx_pending.where("created_at < ?",
                                                           10.minutes.ago).limit(100)
    pending_transactions.each do |tx|
      committed_tx = CkbTransaction.find_by(tx_hash: tx.tx_hash, tx_status: "committed")
      if committed_tx && tx.reload.tx_pending?
        tx.cell_inputs.delete_all
        tx.delete
      else
        response_string = CkbSync::Api.instance.directly_single_call_rpc method: "get_transaction",
                                                                         params: [tx.tx_hash]
        reason = response_string["result"]["tx_status"]

        if reason["status"] == "rejected"
          ApplicationRecord.transaction do
            tx.update! tx_status: "rejected"
            tx.cell_outputs.update_all(status: "rejected")
            tx.create_reject_reason!(message: reason["reason"])
          end
        end

        if reason["status"] == "unknown"
          ApplicationRecord.transaction do
            tx.update! tx_status: "rejected"
            tx.cell_outputs.update_all(status: "rejected")
            tx.create_reject_reason!(message: "unknown")
          end
        end
      end
    end
  end
end
