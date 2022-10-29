class PoolTransactionCheckWorker
  include Sidekiq::Worker
  @@latest_json_rpc_id = 0

  # currently there's no such method in Ruby SDK, so let's use HTTP post request.
  def get_failed_reason options
    payload = {
      "id": options[:json_rpc_id],
      "jsonrpc": "2.0",
      "method": "get_transaction",
      "params": [options[:tx_id]]
    }

    url = ENV['CKB_NODE_URL']
    Rails.logger.debug {"== in get_failed_reason, url: #{url}, payload: #{payload}"}

    res = HTTP.post(url, json: payload)
    data = JSON.parse res.to_s
    Rails.logger.debug {"== in get_failed_reason, result: #{data.inspect}"}

    status = data['result']['tx_status']['status']
    reason = ''
    if status == 'rejected'
      reason = data['result']['tx_status']['reason']
    else
      reason = 'good'
    end
    return {id: options[:json_rpc_id], reason: reason.to_s, status: status}
  end

  def generate_json_rpc_id
    @@latest_json_rpc_id += 1
    return @@latest_json_rpc_id
  end

  def perform
    PoolTransactionEntry.pool_transaction_pending.select(:id, :tx_hash, :inputs, :created_at, :cell_deps).find_each do |tx|
      reason = get_failed_reason tx_id: tx.tx_hash, json_rpc_id: generate_json_rpc_id
      if reason[:status] == 'rejected'
        tx.update(tx_status: "rejected", detailed_message: reason[:reason])
      end
    end
  end
end
