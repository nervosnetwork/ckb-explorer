class PoolTransactionUpdateRejectReasonWorker
  include Sidekiq::Worker
  def perform tx_hash, transaction_attributes_hash

    response_string = CkbSync::Api.instance.directly_single_call_rpc method: 'get_transaction', params: [tx_hash]
    reason = response_string['result']['tx_status']

    if reason['status'] == 'rejected'
      transaction_attributes_hash[:detailed_message] = reason['reason']
      PoolTransactionEntry.upsert transaction_attributes_hash
    end
  end
end
