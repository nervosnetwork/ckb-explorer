module CellDataComparator
  extend ActiveSupport::Concern

  private

  def compare_cells(transaction)
    inputs = transaction.input_cells
    outputs = transaction.cell_outputs
    normal_transfers = diff_normal_cells(inputs, outputs)
    udt_transfers = diff_udt_cells(inputs, outputs)
    cota_nft_transfers = diff_cota_nft_cells(transaction, inputs, outputs)
    normal_nft_transfers = diff_normal_nft_cells(inputs, outputs)
    nft_class_transfers = diff_nft_capacities(inputs, outputs)

    merged_transfers =
      [normal_transfers, udt_transfers, cota_nft_transfers, normal_nft_transfers, nft_class_transfers].reduce do |acc, h|
        acc.merge(h) { |_, ov, nv| ov + nv }
      end

    merged_transfers.map do |address_id, transfers|
      address = Address.find_by(id: address_id)
      { address: address.address_hash, transfers: }
    end
  end

  def diff_normal_cells(inputs, outputs)
    transfers = Hash.new { |h, k| h[k] = Array.new }
    inputs = inputs.normal.group(:address_id).sum(:capacity)
    outputs = outputs.normal.group(:address_id).sum(:capacity)

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
      info = Udt.find_by(type_hash: c.type_hash, published: true)
      unless udt_infos[c.type_hash]
        udt_infos[c.type_hash] = {
          symbol: info&.symbol,
          decimal: info&.decimal,
          display_name: info&.display_name,
          type_hash: c.type_hash,
          uan: info&.uan,
        }
      end

      k = [c.address_id, c.type_hash]
      h[k] ||= { capacity: 0.0, amount: 0.0 }
      h[k][:capacity] += c.capacity
      h[k][:amount] += c.udt_amount
    }
    inputs = inputs.udt.each_with_object({}) { |c, h| process_udt.call(c, h) }
    outputs = outputs.udt.each_with_object({}) { |c, h| process_udt.call(c, h) }

    (inputs.keys | outputs.keys).each do |k|
      input = inputs[k]
      output = outputs[k]

      amount = output&.dig(:amount).to_f - input&.dig(:amount).to_f
      capacity = output&.dig(:capacity).to_f - input&.dig(:capacity).to_f
      udt_info = udt_infos[k[1]].merge(amount:)
      transfers[k[0]] << CkbUtils.hash_value_to_s({ capacity:, cell_type: "udt", udt_info: })
    end

    transfers
  end

  def diff_cota_nft_cells(transaction, inputs, outputs)
    transfers = Hash.new { |h, k| h[k] = Array.new }
    inputs = inputs.cota_regular.group(:address_id).sum(:capacity)
    outputs = outputs.cota_regular.group(:address_id).sum(:capacity)

    (inputs.keys | outputs.keys).each do |k|
      capacity = outputs[k].to_f - inputs[k].to_f
      transfers[k] << { capacity: capacity.to_s, cell_type: "cota_regular", cota_info: cota_info(transaction, k) }
    end

    transfers
  end

  def diff_normal_nft_cells(inputs, outputs)
    transfers = Hash.new { |h, k| h[k] = Array.new }
    cell_types = %w(m_nft_token nrc_721_token spore_cell)

    process_nft = ->(c, h) {
      k = [c.address_id, c.cell_type, c.type_hash]
      h[k] ||= { capacity: 0.0, count: 0 }
      h[k][:capacity] += c.capacity
      h[k][:count] -= 1
    }
    inputs = inputs.where(cell_type: cell_types).each_with_object({}) { |c, h| process_nft.call(c, h) }
    outputs = outputs.where(cell_type: cell_types).each_with_object({}) { |c, h| process_nft.call(c, h) }

    (inputs.keys | outputs.keys).each do |k|
      address_id, cell_type, type_hash = k
      token_id, collection_name = token_info(type_hash)
      input = inputs[k]
      output = outputs[k]
      capacity = output&.dig(:capacity).to_f - input&.dig(:capacity).to_f
      count = output&.dig(:count).to_i + input&.dig(:count).to_i
      transfers[address_id] << CkbUtils.hash_value_to_s({ capacity:, cell_type:, token_id:, collection_name:, count: })
    end

    transfers
  end

  def diff_nft_capacities(inputs, outputs)
    transfers = Hash.new { |h, k| h[k] = Array.new }
    cell_types = %w(m_nft_issuer m_nft_class nrc_721_factory cota_registry spore_cluster)
    inputs = inputs.where(cell_type: cell_types).group(:address_id, :cell_type).sum(:capacity)
    outputs = outputs.where(cell_type: cell_types).group(:address_id, :cell_type).sum(:capacity)

    (inputs.keys | outputs.keys).each do |k|
      capacity = outputs[k].to_f - inputs[k].to_f
      transfers[k[0]] << CkbUtils.hash_value_to_s({ capacity:, cell_type: k[1] })
    end

    transfers
  end

  def token_info(script_hash)
    item = TokenItem.joins(:type_script).where(type_script: { script_hash: }).take
    [item&.token_id, item&.collection&.name]
  end

  def cota_info(transaction, address_id)
    info = Array.new
    process_transfer = ->(item, count) {
      collection = item.collection
      info << CkbUtils.hash_value_to_s({
        collection_name: collection.name,
        count:,
        token_id: item.token_id,
      })
    }

    transaction.token_transfers.each do |t|
      process_transfer.call(t.item, -1) if t.from_id == address_id
      process_transfer.call(t.item, 1) if t.to_id == address_id
    end

    info
  end
end
