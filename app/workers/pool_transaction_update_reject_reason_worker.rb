class PoolTransactionUpdateRejectReasonWorker
  include Sidekiq::Worker
  def perform(tx_hash)
    response_string = CkbSync::Api.instance.directly_single_call_rpc method: "get_transaction",
                                                                     params: [tx_hash]
    reason = response_string["result"]["tx_status"]
    if reason["status"] == "rejected"
      tx = CkbTransaction.find_by tx_hash: tx_hash
      reject_reason = tx.reject_reason || tx.build_reject_reason
      tx.update tx_status: "rejected"
      reject_reason.update message: reason["reason"]
    end
  end
end
