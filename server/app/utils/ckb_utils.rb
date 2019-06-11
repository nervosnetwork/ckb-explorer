class CkbUtils
  def self.calculate_cell_min_capacity(output)
    output = output
    capacity = 8 + output.data.bytesize + calculate_script_capacity(output.lock)
    if output.type.present?
      capacity += calculate_script_capacity(output.type)
    end
    capacity
  end

  def self.calculate_script_capacity(script)
    capacity = 1 + (script.args || []).map(&:bytesize).reduce(0, &:+)
    if script.code_hash
      capacity += CKB::Utils.hex_to_bin(script.code_hash).bytesize
    end
    capacity
  end

  def self.block_cell_consumed(transactions)
    transactions.reduce(0) do |memo, transaction|
      memo + transaction.outputs.reduce(0) { |inside_memo, output| inside_memo + calculate_cell_min_capacity(output) }
    end
  end

  def self.total_cell_capacity(transactions)
    transactions.reduce(0) do |memo, transaction|
      memo + transaction.outputs.reduce(0) { |inside_memo, output| inside_memo + output.capacity.to_i }
    end
  end

  def self.miner_hash(cellbase)
    lock_script = cellbase.outputs.first.lock
    generate_address(lock_script)
  end

  def self.generate_address(lock_script)
    return unless use_default_lock_script?(lock_script)

    type1_address(lock_script)
  end

  def self.type1_address(lock_script)
    blake160 = lock_script.args.first
    return if blake160.blank? || !CKB::Utils.valid_hex_string?(blake160)

    target_pubkey_blake160_bin = [blake160[2..-1]].pack("H*")
    type = ["01"].pack("H*")
    bin_idx = ["P2PH".each_char.map { |c| c.ord.to_s(16) }.join].pack("H*")
    payload = type + bin_idx + target_pubkey_blake160_bin
    CKB::ConvertAddress.encode(Address::PREFIX_TESTNET, payload)
  end

  def self.use_default_lock_script?(lock_script)
    code_hash = lock_script.code_hash

    return false if code_hash.blank?

    code_hash == ENV["CODE_HASH"]
  end

  def self.parse_address(address_hash)
    decoded_prefix, data = CKB::ConvertAddress.decode(address_hash)
    raise "Invalid prefix" if decoded_prefix != Address::PREFIX_TESTNET
    raise "Invalid type/bin-idx" if data.slice(0..4) != ["0150325048"].pack("H*")

    CKB::Utils.bin_to_hex(data.slice(5..-1))
  end

  def self.miner_reward(cellbase)
    cellbase.outputs.first.capacity
  end

  def self.get_epoch_info(epoch)
    Rails.cache.fetch("epoch_#{epoch}", expires_in: 1.day) do
      CkbSync::Api.instance.get_epoch_by_number(epoch)
    end
  end

  def self.ckb_transaction_fee(ckb_transaction)
    cell_output_capacities = ckb_transaction.cell_outputs.sum(:capacity)
    previous_cell_output_capacities = 0
    return if CellInput.where(ckb_transaction: ckb_transaction, from_cell_base: false, previous_cell_output_id: nil).exists?

    previous_cell_output_ids = CellInput.where(ckb_transaction: ckb_transaction, from_cell_base: false).select("previous_cell_output_id")

    if previous_cell_output_ids.exists?
      previous_cell_output_capacities = CellOutput.where(id: previous_cell_output_ids).sum(:capacity)
    end

    previous_cell_output_capacities.zero? ? 0 : (previous_cell_output_capacities - cell_output_capacities)
  end

  def self.transaction_fee(transaction)
    cell_output_capacities = transaction.outputs.sum { |output| output.capacity.to_i }
    cell_input_capacities = transaction.inputs.map(&method(:cell_input_capacity))

    calculate_transaction_fee(cell_input_capacities, cell_output_capacities)
  end

  def self.get_unspent_cells(address_hash)
    return if address_hash.blank?

    address = Address.find_by(address_hash: address_hash)
    address.cell_outputs.live
  end

  def self.get_balance(address_hash)
    return if address_hash.blank?

    get_unspent_cells(address_hash).sum(:capacity)
  end

  def self.address_cell_consumed(address_hash)
    return if address_hash.blank?

    address_cell_consumed = 0
    get_unspent_cells(address_hash).find_each do |cell_output|
      address_cell_consumed += calculate_cell_min_capacity(cell_output.node_cell_output)
    end

    address_cell_consumed
  end

  def self.cell_input_capacity(cell_input)
    cell = cell_input.previous_output.cell

    if cell.blank?
      0
    else
      previous_transaction_hash = cell.tx_hash
      previous_output_index = cell.index.to_i

      previous_output = CellOutput.find_by(tx_hash: previous_transaction_hash, cell_index: previous_output_index)
      return if previous_output.blank?

      previous_output.capacity
    end
  end

  def self.calculate_transaction_fee(cell_input_capacities, cell_output_capacities)
    return if cell_input_capacities.include?(nil)

    input_capacities = cell_input_capacities.reduce(0, &:+)
    input_capacities.zero? ? 0 : (input_capacities - cell_output_capacities)
  end
end
