class PoolTransactionEntry < ApplicationRecord
  enum tx_status: { pending: 0, proposed: 1, committed: 2, rejected: 3 }, _prefix: :pool_transaction

  def is_cellbase
    false
  end

  def income(address = nil)
    nil
  end

  def display_outputs(previews: false)
    self.attributes["display_outputs"]
  end

  def display_inputs(previews: false)
    self.attributes["display_inputs"]
  end

  def proposal_short_id
    tx_hash[0...12]
  end

  def display_inputs_info; end

  def to_raw
    {
      hash: tx_hash,
      header_deps: Array.wrap(header_deps),
      cell_deps: Array.wrap(cell_deps).map do |d|
        d["out_point"]["index"] = "0x#{d['out_point']['index'].to_s(16)}"
        d
      end,
      inputs: Array.wrap(inputs).map do |i|
                i["since"] = "0x#{i['since'].to_s(16)}"
                i
              end,
      outputs: Array.wrap(outputs).map do |i|
                 i["capacity"] = "0x#{i['capacity'].to_s(16)}"
                 i
               end,
      outputs_data: Array.wrap(outputs_data),
      version: "0x#{(version || 0).to_s(16)}",
      witnesses: Array.wrap(witnesses)
    }
  end

  def update_detailed_message_for_rejected_transaction

    response_string = CkbSync::Api.instance.directly_single_call_rpc method: 'get_transaction', params: [tx_hash]
    reason = response_string['result']['tx_status']
    self.update detailed_message: response_string['result']['tx_status']['reason']
    return self
  end

end

# == Schema Information
#
# Table name: pool_transaction_entries
#
#  id               :bigint           not null, primary key
#  cell_deps        :jsonb
#  tx_hash          :binary
#  header_deps      :jsonb
#  inputs           :jsonb
#  outputs          :jsonb
#  outputs_data     :jsonb
#  version          :integer
#  witnesses        :jsonb
#  transaction_fee  :decimal(30, )
#  block_number     :decimal(30, )
#  block_timestamp  :decimal(30, )
#  cycles           :decimal(30, )
#  tx_size          :decimal(30, )
#  display_inputs   :jsonb
#  display_outputs  :jsonb
#  tx_status        :integer          default("pending")
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  detailed_message :text
#  bytes            :integer          default(0)
#
# Indexes
#
#  index_pool_transaction_entries_on_id_and_tx_status  (id,tx_status)
#  index_pool_transaction_entries_on_tx_hash           (tx_hash) UNIQUE
#  index_pool_transaction_entries_on_tx_status         (tx_status)
#
