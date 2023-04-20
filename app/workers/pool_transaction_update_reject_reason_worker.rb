class PoolTransactionUpdateRejectReasonWorker
  include Sidekiq::Worker
  def perform(tx_hash)
    response_string = CkbSync::Api.instance.directly_single_call_rpc method: "get_transaction",
                                                                     params: [tx_hash]
    reason = response_string["result"]["tx_status"]
    if reason["status"] == "rejected"
      PoolTransactionEntry.
        where(tx_hash: tx_hash).
        update_all tx_status: "rejected",
                   detailed_message: reason["reason"]
    end
  end
end
