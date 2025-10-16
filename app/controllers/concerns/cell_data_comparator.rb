module CellDataComparator
  extend ActiveSupport::Concern

  private

  def compare_cells(transaction)
    combine_transfers(transaction).map do |address, transfers|
      { address: address.address_hash, transfers: }
    end
  end

  def combine_transfers(transaction)
    inputs = transaction.input_cells
    outputs = transaction.cell_outputs
    normal_transfers = diff_normal_cells(inputs, outputs)
    udt_transfers = diff_udt_cells(inputs, outputs)
    cota_nft_transfers = diff_cota_nft_cells(transaction, inputs, outputs)
    normal_nft_transfers = diff_normal_nft_cells(inputs, outputs)
    dao_transfers = diff_dao_capacities(inputs, outputs)

    [normal_transfers, udt_transfers, cota_nft_transfers, normal_nft_transfers, dao_transfers].reduce do |acc, h|
      acc.merge(h) { |_, ov, nv| ov + nv }
    end
  end

  def diff_normal_cells(inputs, outputs)
    transfers = Hash.new { |h, k| h[k] = Array.new }
    inputs = inputs.find_all{|i| i.cell_type.to_s == "normal" }.group_by(&:address).transform_values do |items|
      items.sum { |item| item[:capacity] }
    end

    outputs = outputs.find_all{|i| i.cell_type.to_s == "normal" }.group_by(&:address).transform_values do |items|
      items.sum { |item| item[:capacity] }
    end 

    (inputs.keys | outputs.keys).each do |k|
      capacity = outputs[k].to_f - inputs[k].to_f
      transfers[k] << CkbUtils.hash_value_to_s({ capacity:, cell_type: "normal" })
    end

    transfers
  end

  def diff_udt_cells(inputs, outputs)
    transfers = Hash.new { |h, k| h[k] = Array.new }
    udt_infos = Hash.new { |h, k| h[k] = nil }

    process_udt = ->(c, h) {
      info = c.udt_cell
      unless udt_infos[c.type_hash]
        udt_infos[c.type_hash] = {
          symbol: info&.symbol,
          decimal: info&.decimal,
          type_hash: c.type_hash,
        }
      end

      k = [c.address, c.type_hash, c.cell_type]
      h[k] ||= { capacity: 0.0, amount: 0.0 }
      h[k][:capacity] += c.capacity
      h[k][:amount] += c.udt_amount.to_f
    }

    cell_types = %w(udt omiga_inscription xudt xudt_compatible)

    inputs = inputs.find_all{|i| cell_types.include?(i.cell_type.to_s) }.each_with_object({}) { |c, h| process_udt.call(c, h) }
    outputs = outputs.find_all{|i| cell_types.include?(i.cell_type.to_s) }.each_with_object({}) { |c, h| process_udt.call(c, h) }

    (inputs.keys | outputs.keys).each do |k|
      input = inputs[k]
      output = outputs[k]

      amount = output&.dig(:amount).to_f - input&.dig(:amount).to_f
      capacity = output&.dig(:capacity).to_f - input&.dig(:capacity).to_f
      udt_info = udt_infos[k[1]].merge(amount: "%f" % amount)
      transfers[k[0]] << CkbUtils.hash_value_to_s({ capacity:, cell_type: k[2], udt_info: })
    end

    transfers
  end

  def diff_dao_capacities(inputs, outputs)
    transfers = Hash.new { |h, k| h[k] = Array.new }
    cell_types = %w(nervos_dao_deposit nervos_dao_withdrawing)

    inputs = inputs.find_all{|i| cell_types.include?(i.cell_type.to_s) }.group_by{|i| [i.address, i.cell_type] }.transform_values do |items|
      items.sum { |item| item[:capacity] }
    end

    outputs = outputs.find_all{|i| cell_types.include?(i.cell_type.to_s) }.group_by{|i| [i.address, i.cell_type] }.transform_values do |items|
      items.sum { |item| item[:capacity] }
    end

    (inputs.keys | outputs.keys).each do |k|
      capacity = outputs[k].to_f - inputs[k].to_f
      transfers[k[0]] << CkbUtils.hash_value_to_s({ capacity:, cell_type: k[1] })
    end

    transfers
  end

  def diff_cota_nft_cells(transaction, inputs, outputs)
    transfers = Hash.new { |h, k| h[k] = Array.new }

    inputs = inputs.find_all{|i| i.cell_type.to_s == 'cota_regular' }.group_by(&:address).transform_values do |items|
      items.sum { |item| item[:capacity] }
    end 

    outputs = outputs.find_all{|i| i.cell_type.to_s == 'cota_regular' }.group_by(&:address).transform_values do |items|
      items.sum { |item| item[:capacity] }
    end 

    (inputs.keys | outputs.keys).each do |k|
      capacity = outputs[k].to_f - inputs[k].to_f
      transfers[k] << { capacity: capacity.to_s, cell_type: "cota_regular", cota_info: cota_info(transaction, k) }
    end

    transfers
  end

  def diff_normal_nft_cells(inputs, outputs)
    transfers = Hash.new { |h, k| h[k] = Array.new }
    nft_infos = Hash.new { |h, k| h[k] = nil }
    cell_types = %w(m_nft_token nrc_721_token spore_cell did_cell m_nft_issuer
                    m_nft_class nrc_721_factory cota_registry spore_cluster)

    process_nft = ->(c, h, o) {
      k = [c.address, c.cell_type, c.type_hash]
      h[k] ||= { capacity: 0.0, count: 0 }
      h[k][:capacity] += c.capacity
      h[k][:count] += o

      unless nft_infos[c.type_hash]
        nft_infos[c.type_hash] = nft_info(c)
      end
    }
    inputs = inputs.find_all{|i| cell_types.include?(i.cell_type.to_s) }.each_with_object({}) { |c, h| process_nft.call(c, h, -1) }
    outputs = outputs.find_all{|i| cell_types.include?(i.cell_type.to_s) }.each_with_object({}) { |c, h| process_nft.call(c, h, 1) }

    (inputs.keys | outputs.keys).each do |k|
      address, cell_type, type_hash = k
      input = inputs[k]
      output = outputs[k]
      capacity = output&.dig(:capacity).to_f - input&.dig(:capacity).to_f
      count = output&.dig(:count).to_i + input&.dig(:count).to_i
      transfer = { capacity:, cell_type:, count: }
      transfer.merge!(nft_infos[type_hash]) if nft_infos[type_hash]
      transfers[address] << CkbUtils.hash_value_to_s(transfer)
    end

    transfers
  end

  def nft_info(cell)
    case cell.cell_type
    when "m_nft_token", "nrc_721_token", "spore_cell", "did_cell"
      item = TokenItem.joins(:type_script).where(type_script: { script_hash: cell.type_hash }).take
      { token_id: item&.token_id, name: item&.collection&.name }
    when "m_nft_issuer"
      { name: CkbUtils.parse_issuer_data(cell.data).info["name"] }
    when "m_nft_class"
      { name: CkbUtils.parse_token_class_data(cell.data).name }
    when "nrc_721_factory"
      type_script = cell.type_script
      factory_cell = NrcFactoryCell.find_by(
        code_hash: type_script.code_hash,
        hash_type: type_script.hash_type,
        args: type_script.args,
        verified: true,
      )
      { name: factory_cell&.name }
    when "spore_cluster"
      { name: CkbUtils.parse_spore_cluster_data(cell.data)[:name] }
    end
  end

  def cota_info(transaction, address)
    info = Array.new
    process_transfer = ->(item, count) {
      collection = item.collection
      info << CkbUtils.hash_value_to_s(
        {
          name: collection.name,
          count:,
          token_id: item.token_id,
        },
      )
    }

    transaction.token_transfers.each do |t|
      process_transfer.call(t.item, -1) if t.from_id == address.id
      process_transfer.call(t.item, 1) if t.to_id == address.id
    end

    info
  end
end
