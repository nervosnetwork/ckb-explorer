class PoolTransactionEntry < ApplicationRecord
  enum tx_status: { pending: 0, proposed: 1, committed: 2, rejected: 3 },
       _prefix: :pool_transaction

  def block
    nil
  end

  def is_cellbase
    false
  end

  def income(address = nil)
    nil
  end

  def display_outputs(previews: false)
    cell_inputs_for_display = cell_inputs.to_a.sort_by(&:id)
    if previews
      cell_inputs_for_display = cell_inputs_for_display[0, 10]
    end
    cell_inputs_for_display.each_with_index.map do |cell_input, index|
      previous_cell_output = cell_input.previous_cell_output

      display_input = {
        id: previous_cell_output.id,
        from_cellbase: false,
        capacity: previous_cell_output.capacity,
        address_hash: previous_cell_output.address_hash,
        generated_tx_hash: previous_cell_output.generated_by.tx_hash,
        cell_index: previous_cell_output.cell_index,
        cell_type: previous_cell_output.cell_type,
        since: {
          raw: hex_since(cell_input.since.to_i),
          median_timestamp: cell_input.block.median_timestamp.to_i
        }
      }
      display_input.merge!(attributes_for_dao_input(previous_cell_output)) if previous_cell_output.nervos_dao_withdrawing?
      display_input.merge!(attributes_for_dao_input(cell_outputs[index], false)) if previous_cell_output.nervos_dao_deposit?
      display_input.merge!(attributes_for_udt_cell(previous_cell_output)) if previous_cell_output.udt?
      display_input.merge!(attributes_for_m_nft_cell(previous_cell_output)) if previous_cell_output.cell_type.in?(%w(m_nft_issuer m_nft_class m_nft_token))
      display_input.merge!(attributes_for_nrc_721_cell(previous_cell_output)) if previous_cell_output.cell_type.in?(%w(nrc_721_token nrc_721_factory))

      CkbUtils.hash_value_to_s(display_input)
    end
  end

  def display_inputs(previews: false)
    if is_cellbase
      cellbase_display_inputs
    else
      normal_tx_display_inputs(previews)
    end
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
    response_string = CkbSync::Api.instance.directly_single_call_rpc method: "get_transaction",
                                                                     params: [tx_hash]
    reason = response_string["result"]["tx_status"]
    self.update detailed_message: response_string["result"]["tx_status"]["reason"]
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
#  index_pool_transaction_entries_on_tx_hash           (tx_hash) USING hash
#  index_pool_transaction_entries_on_tx_status         (tx_status)
#  unique_tx_hash                                      (tx_hash) UNIQUE
#
