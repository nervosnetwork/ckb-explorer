class CkbUtils
  def self.calculate_cell_min_capacity(output, data)
    output.calculate_min_capacity(data)
  end

  def self.block_cell_consumed(transactions)
    transactions.reduce(0) do |memo, transaction|
      outputs_data = transaction.outputs_data
      transaction.outputs.each_with_index do |output, cell_index|
        memo += calculate_cell_min_capacity(output, outputs_data[cell_index])
      end
      memo
    end
  end

  def self.total_cell_capacity(transactions)
    transactions.flat_map(&:outputs).reduce(0) { |memo, output| memo + output.capacity.to_i }
  end

  def self.miner_hash(cellbase)
    return if cellbase.witnesses.blank?

    lock_script = generate_lock_script_from_cellbase(cellbase)
    generate_address(lock_script)
  end

  def self.miner_lock_hash(cellbase)
    return if cellbase.witnesses.blank?

    lock_script = generate_lock_script_from_cellbase(cellbase)
    lock_script.compute_hash
  end

  def self.generate_lock_script_from_cellbase(cellbase)
    cellbase_witness = cellbase.witnesses.first.delete_prefix("0x")
    cellbase_witness_serialization = [cellbase_witness].pack("H*")
    script_offset = [cellbase_witness_serialization[4..7].unpack1("H*")].pack("H*").unpack1("V")
    message_offset = [cellbase_witness_serialization[8..11].unpack1("H*")].pack("H*").unpack1("V")
    script_serialization = cellbase_witness_serialization[script_offset...message_offset]
    code_hash_offset = [script_serialization[4..7].unpack1("H*")].pack("H*").unpack1("V")
    hash_type_offset = [script_serialization[8..11].unpack1("H*")].pack("H*").unpack1("V")
    args_offset = [script_serialization[12..15].unpack1("H*")].pack("H*").unpack1("V")
    code_hash_serialization = script_serialization[code_hash_offset...hash_type_offset]
    hash_type_serialization = script_serialization[hash_type_offset...args_offset]
    args_serialization = script_serialization[hash_type_offset + 1..-1]
    args_serialization = args_serialization[4..-1]

    code_hash = "0x#{code_hash_serialization.unpack1('H*')}"
    hash_type_hex = "0x#{hash_type_serialization.unpack1('H*')}"
    args = "0x#{args_serialization.unpack1('H*')}"

    hash_type = hash_type_hex == "0x00" ? "data" : "type"
    CKB::Types::Script.new(code_hash: code_hash, args: args, hash_type: hash_type)
  end

  def self.generate_address(lock_script)
    CKB::Address.new(lock_script, mode: ENV["CKB_NET_MODE"]).generate
  end

  def self.parse_address(address_hash)
    CKB::AddressParser.new(address_hash).parse
  end

  def self.block_reward(node_block_header)
    cellbase_output_capacity_details = CkbSync::Api.instance.get_cellbase_output_capacity_details(node_block_header.hash)
    primary_reward(node_block_header, cellbase_output_capacity_details) + secondary_reward(node_block_header, cellbase_output_capacity_details)
  end

  def self.base_reward(block_number, epoch_number)
    return 0 if block_number.to_i < 12

    epoch_info = get_epoch_info(epoch_number)
    start_number = epoch_info.start_number.to_i
    epoch_reward = ENV["DEFAULT_EPOCH_REWARD"].to_i
    base_reward = epoch_reward / epoch_info.length.to_i
    remainder_reward = epoch_reward % epoch_info.length.to_i
    if block_number.to_i >= start_number && block_number.to_i < start_number + remainder_reward
      base_reward + 1
    else
      base_reward
    end
  end

  def self.primary_reward(node_block_header, cellbase_output_capacity_details)
    node_block_header.number.to_i != 0 ? cellbase_output_capacity_details.primary.to_i : 0
  end

  def self.secondary_reward(node_block_header, cellbase_output_capacity_details)
    node_block_header.number.to_i != 0 ? cellbase_output_capacity_details.secondary.to_i : 0
  end

  def self.get_epoch_info(epoch)
    CkbSync::Api.instance.get_epoch_by_number(epoch)
  end

  # The lower 56 bits of the epoch number field are split into 3 parts(listed in the order from higher bits to lower bits):
  # The highest 16 bits represent the epoch length
  # The next 16 bits represent the current block index in the epoch
  # The lowest 24 bits represent the current epoch number
  def self.parse_epoch_info(header)
    epoch = header.epoch
    return get_epoch_info(epoch) if epoch.zero?

    parsed_epoch = parse_epoch(epoch)
    start_number = header.number - parsed_epoch.index

    OpenStruct.new(number: parsed_epoch.number, length: parsed_epoch.length, start_number: start_number)
  end

  def self.parse_epoch(epoch)
    OpenStruct.new(
      length: (epoch >> 40) & 0xFFFF,
      index: (epoch >> 24) & 0xFFFF,
      number: (epoch) & 0xFFFFFF
    )
  end

  def self.ckb_transaction_fee(ckb_transaction, input_capacities, output_capacities)
    if ckb_transaction.inputs.where(cell_type: "nervos_dao_withdrawing").present?
      dao_withdraw_tx_fee(ckb_transaction)
    else
      normal_tx_fee(input_capacities, output_capacities)
    end
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
      address_cell_consumed += calculate_cell_min_capacity(cell_output.node_output, cell_output.data)
    end

    address_cell_consumed
  end

  def self.update_block_reward!(current_block)
    target_block_number = current_block.target_block_number
    target_block = current_block.target_block
    return if target_block_number < 1 || target_block.blank?

    block_header = Struct.new(:hash, :number)
    cellbase_output_capacity_details = CkbSync::Api.instance.get_cellbase_output_capacity_details(current_block.block_hash)
    reward = CkbUtils.block_reward(block_header.new(current_block.block_hash, current_block.number))
    primary_reward = CkbUtils.primary_reward(block_header.new(current_block.block_hash, current_block.number), cellbase_output_capacity_details)
    secondary_reward = CkbUtils.secondary_reward(block_header.new(current_block.block_hash, current_block.number), cellbase_output_capacity_details)
    target_block.update!(reward_status: "issued", reward: reward, primary_reward: primary_reward, secondary_reward: secondary_reward)
    current_block.update!(target_block_reward_status: "issued")
  end

  def self.calculate_received_tx_fee!(current_block)
    target_block_number = current_block.target_block_number
    target_block = current_block.target_block
    return if target_block_number < 1 || target_block.blank?

    cellbase = Cellbase.new(current_block)
    proposal_reward = cellbase.proposal_reward
    commit_reward = cellbase.commit_reward
    received_tx_fee = commit_reward + proposal_reward
    target_block.update!(received_tx_fee: received_tx_fee, received_tx_fee_status: "calculated")
  end

  def self.update_current_block_mining_info(block)
    return if block.blank?

    miner_address = block.miner_address
    MiningInfo.create!(block: block, block_number: block.number, address: miner_address, status: "mined")
    miner_address.increment!(:mined_blocks_count)
  end

  def self.normal_tx_fee(input_capacities, output_capacities)
    input_capacities - output_capacities
  end

  def self.dao_withdraw_tx_fee(ckb_transaction)
    nervos_dao_withdrawing_cells = ckb_transaction.inputs.nervos_dao_withdrawing
    interests = nervos_dao_withdrawing_cells.reduce(0) { |memo, nervos_dao_withdrawing_cell| memo + dao_interest(nervos_dao_withdrawing_cell) }

    ckb_transaction.inputs.sum(:capacity) + interests - ckb_transaction.outputs.sum(:capacity)
  end

  def self.dao_interest(nervos_dao_withdrawing_cell)
    nervos_dao_withdrawing_cell_generated_tx = nervos_dao_withdrawing_cell.generated_by
    nervos_dao_deposit_cell = nervos_dao_withdrawing_cell_generated_tx.cell_inputs.order(:id)[nervos_dao_withdrawing_cell.cell_index].previous_cell_output
    deposit_out_point = CKB::Types::OutPoint.new(tx_hash: nervos_dao_deposit_cell.tx_hash, index: nervos_dao_deposit_cell.cell_index)
    withdrawing_dao_cell_block_hash = nervos_dao_withdrawing_cell.block.block_hash
    CkbSync::Api.instance.calculate_dao_maximum_withdraw(deposit_out_point, withdrawing_dao_cell_block_hash).hex - nervos_dao_deposit_cell.capacity.to_i
  rescue CKB::RPCError
    0
  end

  def self.compact_to_difficulty(compact)
    target, overflow = compact_to_target(compact)
    if target.zero? || overflow
      return 0
    end

    target_to_difficulty(target)
  end

  def self.compact_to_target(compact)
    exponent = compact >> 24
    mantissa = compact & 0x00ff_ffff

    if exponent <= 3
      mantissa >>= 8 * (3 - exponent)
      ret = mantissa.dup
    else
      ret = mantissa.dup
      ret <<= 8 * (exponent - 3)
    end
    overflow = !mantissa.zero? && exponent > 32

    return ret, overflow
  end

  def self.target_to_difficulty(target)
    u256_max_value = 2**256 - 1
    hspace = "0x10000000000000000000000000000000000000000000000000000000000000000".hex
    if target.zero?
      u256_max_value
    else
      hspace / target
    end
  end

  def self.hash_value_to_s(hash)
    hash.each do |key, value|
      next if !!value == value

      if value.is_a?(Hash)
        hash_value_to_s(value)
      else
        hash[key] = value.to_s
      end
    end
  end

  def self.parse_dao(dao)
    return if dao.blank?

    bin_dao = CKB::Utils.hex_to_bin(dao)
    c_i = bin_dao[0..7].unpack("Q<").pack("Q>").unpack1("H*").hex
    ar_i = bin_dao[8..15].unpack("Q<").pack("Q>").unpack1("H*").hex
    s_i = bin_dao[16..23].unpack("Q<").pack("Q>").unpack1("H*").hex
    u_i = bin_dao[24..-1].unpack("Q<").pack("Q>").unpack1("H*").hex

    OpenStruct.new(c_i: c_i, ar_i: ar_i, s_i: s_i, u_i: u_i)
  end

  def self.parse_udt_cell_data(data)
    return if data.delete_prefix("0x") == ""

    [data.delete_prefix("0x")].pack("H*")[0..15].reverse.unpack1("B*").to_i(2)
  end

  def self.time_in_milliseconds(time)
    (time.to_f * 1000).floor
  end
end
