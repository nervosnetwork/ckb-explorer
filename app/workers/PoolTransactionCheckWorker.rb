class PoolTransactionCheckWorker
  include Sidekiq::Worker
  @latest_json_rpc_id = 0

  # currently there's no such method in Ruby SDK, so let's use HTTP post request.
  def get_failed_reason options
    payload = {
      "id": options[:json_rpc_id],
      "jsonrpc": "2.0",
      "method": "get_transaction",
      "params": [options[:tx_id]]
    }

    url = ENV['CKB_NODE_URL']
    Rails.logger.info "== in get_failed_reason, url: #{url}, payload: #{payload}"

    res = HTTP.post(url, json: payload)
    data = JSON.parse res.to_s

    status = data['result']['tx_status']['status']
    reason = ''
    if status == 'rejected'
      reason = data['result']['tx_status']['reason']
    else
      reason = 'good'
    end
    return {id: json_rpc_id, reason: reason}
  end

  def generate_json_rpc_id
    @latest_json_rpc_id += 1
    return @latest_json_rpc_id
  end

  def perform
    pool_tx_entry_attributes = []
    PoolTransactionEntry.pool_transaction_pending.select(:id, :inputs, :created_at, :cell_deps).each do |tx|

      tx.inputs.each do |input|
        reason = JSON.parse(get_failed_reason tx_id: input["previous_output"]["tx_hash"], json_rpc_id: generate_json_rpc_id)
        if reason['reason'] == 'rejected'
          pool_tx_entry_attributes << { id: tx.id, tx_status: "rejected", detailed_message: reason['reason'], created_at: tx.created_at, updated_at: Time.current }
          break
        end
      end
      tx.cell_deps.each do |input|
        reason = JSON.parse(get_failed_reason tx_id: input["out_point"]["tx_hash"], json_rpc_id: generate_json_rpc_id)
        if reason['reason'] == 'rejected'
          pool_tx_entry_attributes << { id: tx.id, tx_status: "rejected", detailed_message: reason['reason'], created_at: tx.created_at, updated_at: Time.current }
          break
        end
      end
    end

    pool_tx_entry_attributes = pool_tx_entry_attributes.group_by {|tx| tx[:id]}.map {|_, items| items[0]}.flatten
    PoolTransactionEntry.upsert_all(pool_tx_entry_attributes) if pool_tx_entry_attributes.present?
  end
end
