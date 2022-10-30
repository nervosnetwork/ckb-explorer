class PoolTransactionCheckWorker
  include Sidekiq::Worker
  sidekiq_options retry: 0
  @@latest_json_rpc_id = 0

  # currently there's no such method in Ruby SDK, so let's use HTTP post request.
  def get_failed_reason options
    options[:json_rpc_id] ||= generate_json_rpc_id
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
    pool_tx_entry_attributes = []
    # Because iterating over all pool transaction entry record and get tx detail from CKB Node one by one 
    # will make heavy load to CKB node, slowing block processing, sometimes will lead to HTTP timeout
    # So here we directly check the inputs and dependencies of the transaction locally in database
    # If any of the input or dependency cells is used, the transaction will never be valid.
    # Thus we can directly mark this transaction rejected without requesting to CKB Node.
    # Only request the CKB Node for reject reason after we find the transaction is rejeceted.
    PoolTransactionEntry.pool_transaction_pending.select(:id, :tx_hash, :inputs, :created_at, :cell_deps).find_each do |tx|
      rejected = nil
      tx.inputs.each do |input|
        if CellOutput.where(tx_hash: input["previous_output"]["tx_hash"], cell_index: input["previous_output"]["index"], status: "dead").exists?
          rejected = { 
            id: tx.id, 
            tx_status: "rejected", 
            created_at: tx.created_at, 
            updated_at: Time.current 
          }
          break
        end
      end
      unless rejected
        tx.cell_deps.each do |input|
          if CellOutput.where(tx_hash: input["out_point"]["tx_hash"], cell_index: input["out_point"]["index"], status: "dead").exists?
            rejected = { 
              id: tx.id, 
              tx_status: "rejected", 
              created_at: tx.created_at, 
              updated_at: Time.current 
            }
            rejected = true
            break
          end
        end
      end
      if rejected
        reason = get_failed_reason tx_id: tx.tx_hash
        if reason[:status] == 'rejected'
          rejected[:detailed_message] = reason[:reason]
          pool_tx_entry_attributes << rejected
        end
      end
    end

    pool_tx_entry_attributes.uniq!{|i| i[:id]}
    PoolTransactionEntry.upsert_all(pool_tx_entry_attributes) if pool_tx_entry_attributes.present?
  end
end
