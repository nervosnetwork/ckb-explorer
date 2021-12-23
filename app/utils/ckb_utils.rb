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
    parse_cellbase_witness(cellbase).lock
  end

  def self.parse_cellbase_witness(cellbase)
    cellbase_witness = cellbase.witnesses.first.delete_prefix("0x")
    cellbase_witness_serialization = [cellbase_witness].pack("H*")
    script_offset = [cellbase_witness_serialization[4..7].unpack1("H*")].pack("H*").unpack1("V")
    message_offset = [cellbase_witness_serialization[8..11].unpack1("H*")].pack("H*").unpack1("V")
    script_serialization = cellbase_witness_serialization[script_offset...message_offset]
    code_hash_offset = [script_serialization[4..7].unpack1("H*")].pack("H*").unpack1("V")
    hash_type_offset = [script_serialization[8..11].unpack1("H*")].pack("H*").unpack1("V")
    args_offset = [script_serialization[12..15].unpack1("H*")].pack("H*").unpack1("V")
    message_bytes = cellbase_witness_serialization[message_offset..-1]
    message_serialization = message_bytes[4..-1]
    if message_serialization.size > 28
      message = "#{message_serialization[0..28]}#{message_serialization[29..-1]&.unpack1("H*")}".to_json.unpack1("H*")
    else
      message = message_serialization.unpack1("H*")
    end
    code_hash_serialization = script_serialization[code_hash_offset...hash_type_offset]
    hash_type_serialization = script_serialization[hash_type_offset...args_offset]
    args_serialization = script_serialization[hash_type_offset + 1..-1]
    args_serialization = args_serialization[4..-1]

    code_hash = "0x#{code_hash_serialization.unpack1('H*')}"
    hash_type_hex = "0x#{hash_type_serialization.unpack1('H*')}"
    args = "0x#{args_serialization.unpack1('H*')}"

    hash_type = hash_type_hex == "0x00" ? "data" : "type"
    lock = CKB::Types::Script.new(code_hash: code_hash, args: args, hash_type: hash_type)
    OpenStruct.new(lock: lock, message: "0x#{message}")
  end

  def self.miner_message(cellbase)
    parse_cellbase_witness(cellbase).message
  end

  def self.generate_address(lock_script, version = CKB::Address::Version::CKB2021)
    CKB::Address.new(lock_script, mode: ENV["CKB_NET_MODE"], version: version).generate
  end

  def self.parse_address(address_hash)
    CkbAddressParser.new(address_hash).parse
  end

  def self.block_reward(block_number, block_economic_state)
    primary_reward(block_number, block_economic_state) + secondary_reward(block_number, block_economic_state)
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

  def self.primary_reward(block_number, block_economic_state)
    block_number != 0 ? block_economic_state.miner_reward.primary : 0
  end

  def self.secondary_reward(block_number, block_economic_state)
    block_number != 0 ? block_economic_state.miner_reward.secondary : 0
  end

  def self.proposal_reward(block_number, block_economic_state)
    block_number != 0 ? block_economic_state.miner_reward.proposal : 0
  end

  def self.commit_reward(block_number, block_economic_state)
    block_number != 0 ? block_economic_state.miner_reward.committed : 0
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
    if ckb_transaction.is_a?(CkbTransaction)
      return 0 if ckb_transaction.is_cellbase

      if ckb_transaction.inputs.where(cell_type: "nervos_dao_withdrawing").present?
        dao_withdraw_tx_fee(ckb_transaction)
      else
        normal_tx_fee(input_capacities, output_capacities)
      end
    else
      return 0 if ckb_transaction["is_cellbase"]

      if CellOutput.where(consumed_by_id: ckb_transaction["id"], cell_type: "nervos_dao_withdrawing").present?
        dao_withdraw_tx_fee(ckb_transaction)
      else
        normal_tx_fee(input_capacities, output_capacities)
      end
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

    block_economic_state = CkbSync::Api.instance.get_block_economic_state(target_block.block_hash)
    return if block_economic_state.blank?

    reward = CkbUtils.block_reward(target_block.number, block_economic_state)
    primary_reward = CkbUtils.primary_reward(target_block.number, block_economic_state)
    secondary_reward = CkbUtils.secondary_reward(target_block.number, block_economic_state)
    proposal_reward = CkbUtils.proposal_reward(target_block.number, block_economic_state)
    commit_reward = CkbUtils.commit_reward(target_block.number, block_economic_state)
    target_block.update!(reward_status: "issued", reward: reward, primary_reward: primary_reward, secondary_reward: secondary_reward, commit_reward: commit_reward, proposal_reward: proposal_reward)
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
    if ckb_transaction.is_a?(CkbTransaction)
      nervos_dao_withdrawing_cells = ckb_transaction.inputs.nervos_dao_withdrawing
      interests = nervos_dao_withdrawing_cells.reduce(0) { |memo, nervos_dao_withdrawing_cell| memo + dao_interest(nervos_dao_withdrawing_cell) }
      ckb_transaction.inputs.sum(:capacity) + interests - ckb_transaction.outputs.sum(:capacity)
    else
      nervos_dao_withdrawing_cells = CellOutput.where(consumed_by_id: ckb_transaction["id"]).nervos_dao_withdrawing
      interests = nervos_dao_withdrawing_cells.reduce(0) { |memo, nervos_dao_withdrawing_cell| memo + dao_interest(nervos_dao_withdrawing_cell) }
      CellOutput.where(consumed_by_id: ckb_transaction["id"]).sum(:capacity) + interests - CellOutput.where(generated_by: ckb_transaction["id"]).sum(:capacity)
    end
  end

  def self.dao_interest(nervos_dao_withdrawing_cell)
    nervos_dao_withdrawing_cell_generated_tx = nervos_dao_withdrawing_cell.generated_by
    nervos_dao_deposit_cell = nervos_dao_withdrawing_cell_generated_tx.cell_inputs.order(:id)[nervos_dao_withdrawing_cell.cell_index].previous_cell_output
    withdrawing_dao_cell_block_dao = nervos_dao_withdrawing_cell.dao
    DaoCompensationCalculator.new(nervos_dao_deposit_cell, withdrawing_dao_cell_block_dao, nervos_dao_withdrawing_cell).call
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

    CKB::Utils.sudt_amount!(data)
  rescue RuntimeError
    0
  end

  def self.time_in_milliseconds(time)
    (time.to_f * 1000).floor
  end

  def self.cell_type(type_script, output_data)
    return "normal" unless [
      ENV["DAO_CODE_HASH"], ENV["DAO_TYPE_HASH"], ENV["SUDT_CELL_TYPE_HASH"], ENV["SUDT1_CELL_TYPE_HASH"],
      CkbSync::Api.instance.issuer_script_code_hash, CkbSync::Api.instance.token_class_script_code_hash,
      CkbSync::Api.instance.token_script_code_hash
    ].include?(type_script&.code_hash)

    case type_script&.code_hash
    when ENV["DAO_CODE_HASH"], ENV["DAO_TYPE_HASH"]
      if output_data == CKB::Utils.bin_to_hex("\x00" * 8)
        "nervos_dao_deposit"
      else
        "nervos_dao_withdrawing"
      end
    when ENV["SUDT_CELL_TYPE_HASH"], ENV["SUDT1_CELL_TYPE_HASH"]
      if CKB::Utils.hex_to_bin(output_data).bytesize >= CellOutput::MIN_SUDT_AMOUNT_BYTESIZE
        "udt"
      else
        "normal"
      end
    when CkbSync::Api.instance.issuer_script_code_hash
      "m_nft_issuer"
    when CkbSync::Api.instance.token_class_script_code_hash
      "m_nft_class"
    when CkbSync::Api.instance.token_script_code_hash
      "m_nft_token"
    else
      "normal"
    end
  end

  def self.parse_issuer_data(data)
    data = data.delete_prefix("0x")
    version = data[0..1].to_i(16)
    class_count = data[2..9].to_i(16)
    set_count = data[10..17].to_i(16)
    info_size = data[18..21].to_i(16)
    info = JSON.parse([data[22..-1]].pack("H*").force_encoding("UTF-8").encode("UTF-8", invalid: :replace, undef: :replace).delete("\u0000"))
    OpenStruct.new(version: version, class_count: class_count, set_count: set_count, info_size: info_size, info: info)
  rescue
    OpenStruct.new(version: 0, class_count: 0, set_count: 0, info_size: 0, info: "")
  end

  def self.parse_token_class_data(data)
    data = data.delete_prefix("0x")
    version = data[0..1].to_i(16)
    total = data[2..9].to_i(16)
    issued = data[10..17].to_i(16)
    configure = data[18..19].to_i(16)
    name_size = data[20..23].to_i(16)
    name_end_index = (24 + name_size * 2 - 1)
    name = [data[24..name_end_index]].pack("H*").force_encoding("UTF-8").encode("UTF-8", invalid: :replace, undef: :replace).delete("\u0000")
    description_size_start_index = name_end_index + 1
    description_size_end_index = description_size_start_index + 4 - 1
    description_size = data[description_size_start_index..description_size_end_index].to_i(16)
    description_start_index = description_size_end_index + 1
    description_end_index = description_start_index + description_size * 2 - 1
    description = [data[description_start_index..description_end_index]].pack("H*").force_encoding("UTF-8").encode("UTF-8", invalid: :replace, undef: :replace).delete("\u0000")
    renderer_size_start_index = description_end_index + 1
    renderer_size_end_index = renderer_size_start_index + 4 - 1
    renderer_size = data[renderer_size_start_index..renderer_size_end_index].to_i(16)
    renderer_start_index = renderer_size_end_index + 1
    renderer_end_index = renderer_start_index + renderer_size * 2 - 1
    renderer = [data[renderer_start_index, renderer_end_index]].pack("H*").force_encoding("UTF-8").encode("UTF-8", invalid: :replace, undef: :replace).delete("\u0000")
    OpenStruct.new(version: version, total: total, issued: issued, configure: configure, name: name, description: description, renderer: renderer)
  rescue
    OpenStruct.new(version: 0, total: 0, issued: 0, configure: 0, name: "", description: "", renderer: "")
  end

  def self.generate_crc32(str)
    crc = Digest::CRC32.new
    crc.update(str).checksum
  end
end
