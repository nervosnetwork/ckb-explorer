class CkbUtils
  # The block reward halves approximately every 4 years, one epoch is about 4 hours
  HALVING_EPOCH = 4 * 365 * 24 / 4
  MAX_RGBPP_CELL_NUM = 255

  def self.int_to_hex(i)
    "0x#{i.to_s(16)}"
  end

  def self.calculate_cell_min_capacity(output, data)
    output.calculate_min_capacity(data)
  end

  def self.cal_cell_min_capacity(lock_script, type_script, capacity, binary_data)
    lock = CKB::Types::Script.new(**lock_script.to_node)
    type = type_script.present? ? CKB::Types::Script.new(**type_script.to_node) : nil
    CKB::Types::Output.new(capacity: capacity.to_i, lock:, type:)
    CKB::Utils.byte_to_shannon([8, binary_data&.bytesize || 0, lock_script.calculate_bytesize,
                                type_script&.calculate_bytesize || 0].sum)
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
    transactions.flat_map(&:outputs).reduce(0) do |memo, output|
      memo + output.capacity.to_i
    end
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

  # TODO: find the RPC document url
  # @param [CKB::Types::CellbaseWitness] cellbase
  # @return [OpenStruct(lock, message)]
  # message struct: versionbit ｜ binary_version ｜ message
  def self.parse_cellbase_witness(cellbase)
    cellbase_witness = cellbase.witnesses.first.delete_prefix("0x")
    cellbase_witness_serialization = [cellbase_witness].pack("H*")
    script_offset = [cellbase_witness_serialization[4..7].unpack1("H*")].pack("H*").unpack1("V")
    message_offset = [cellbase_witness_serialization[8..11].unpack1("H*")].pack("H*").unpack1("V")
    script_serialization = cellbase_witness_serialization[script_offset...message_offset]
    code_hash_offset = [script_serialization[4..7].unpack1("H*")].pack("H*").unpack1("V")
    hash_type_offset = [script_serialization[8..11].unpack1("H*")].pack("H*").unpack1("V")
    args_offset = [script_serialization[12..15].unpack1("H*")].pack("H*").unpack1("V")
    message_bytes = cellbase_witness_serialization[message_offset..]
    message_serialization = message_bytes[4..]
    message = message_serialization.unpack1("H*")
    code_hash_serialization = script_serialization[code_hash_offset...hash_type_offset]
    hash_type_serialization = script_serialization[hash_type_offset...args_offset]
    args_serialization = script_serialization[hash_type_offset + 1..]
    args_serialization = args_serialization[4..]

    code_hash = "0x#{code_hash_serialization.unpack1('H*')}"
    hash_type_hex = "0x#{hash_type_serialization.unpack1('H*')}"
    args = "0x#{args_serialization.unpack1('H*')}"

    hash_type = hash_type_hex == "0x00" ? "data" : "type"
    lock = CKB::Types::Script.new(code_hash:, args:,
                                  hash_type:)
    OpenStruct.new(lock:, message: "0x#{message}")
  end

  def self.miner_message(cellbase)
    parse_cellbase_witness(cellbase).message
  end

  def self.generate_address(lock_script, version = CKB::Address::Version::CKB2021)
    CKB::Address.new(lock_script, mode: ENV["CKB_NET_MODE"],
                                  version:).generate
  end

  def self.parse_address(address_hash)
    CkbAddressParser.new(address_hash).parse
  end

  def self.block_reward(block_number, block_economic_state)
    primary_reward(block_number,
                   block_economic_state) + secondary_reward(block_number,
                                                            block_economic_state)
  end

  def self.base_reward(block_number, epoch_number)
    return 0 if block_number.to_i < 12

    epoch_info = get_epoch_info(epoch_number)
    start_number = epoch_info.start_number.to_i
    epoch_reward = epoch_reward_with_halving(epoch_number)
    base_reward = epoch_reward / epoch_info.length.to_i
    remainder_reward = epoch_reward % epoch_info.length.to_i
    if block_number.to_i >= start_number && block_number.to_i < start_number + remainder_reward
      base_reward + 1
    else
      base_reward
    end
  end

  def self.epoch_reward_with_halving(epoch_number)
    Settings.default_epoch_reward.to_i >> epoch_number / HALVING_EPOCH
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
  # See https://github.com/nervosnetwork/rfcs/blob/master/rfcs/0027-block-structure/0027-block-structure.md#epoch-uint64
  # @param header [CKB::Types::Header] The block header
  # @return [OpenStruct] The parsed epoch info
  def self.parse_epoch_info(header)
    epoch = header.epoch
    return get_epoch_info(epoch) if epoch.zero?

    parsed_epoch = parse_epoch(epoch)
    start_number = header.number - parsed_epoch.index

    OpenStruct.new(number: parsed_epoch.number, length: parsed_epoch.length,
                   start_number:)
  end

  # This field encodes the epoch number and the fraction position of this block in the epoch.
  # The lower 56 bits of the epoch number field are split into 3 parts(listed in the order from higher bits to lower bits):
  # The highest 16 bits represent the epoch length
  # The next 16 bits represent the current block index in the epoch
  # The lowest 24 bits represent the current epoch number
  # https://github.com/nervosnetwork/rfcs/blob/master/rfcs/0027-block-structure/0027-block-structure.md#epoch-uint64
  # @param epoch [Integer] The lower 56 bits of the epoch number field
  # @return [OpenStruct] The parsed epoch info
  def self.parse_epoch(epoch)
    OpenStruct.new(
      length: (epoch >> 40) & 0xFFFF,
      index: (epoch >> 24) & 0xFFFF,
      number: epoch & 0xFFFFFF,
    )
  end

  # calculate the transaction fee, the fee is the difference between the input and output capacities
  # @param ckb_transaction [CkbTransaction, Hash] The ckb transaction
  # @param input_capacities [Integer] The total input capacities
  # @param output_capacities [Integer] The total output capacities
  # @return [Integer] The transaction fee(in shannon)
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

      if CellOutput.where(consumed_by_id: ckb_transaction["id"],
                          cell_type: "nervos_dao_withdrawing").present?
        dao_withdraw_tx_fee(ckb_transaction)
      else
        normal_tx_fee(input_capacities, output_capacities)
      end
    end
  end

  def self.get_unspent_cells(address_hash)
    return if address_hash.blank?

    address = Address.find_by_address_hash(address_hash)
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
      address_cell_consumed += calculate_cell_min_capacity(
        cell_output.node_output, cell_output.data
      )
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
    primary_reward = CkbUtils.primary_reward(target_block.number,
                                             block_economic_state)
    secondary_reward = CkbUtils.secondary_reward(target_block.number,
                                                 block_economic_state)
    proposal_reward = CkbUtils.proposal_reward(target_block.number,
                                               block_economic_state)
    commit_reward = CkbUtils.commit_reward(target_block.number,
                                           block_economic_state)
    target_block.update!(reward_status: "issued",
                         reward:,
                         primary_reward:,
                         secondary_reward:,
                         commit_reward:,
                         proposal_reward:)
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
    target_block.update!(received_tx_fee:,
                         received_tx_fee_status: "calculated")
  end

  def self.update_current_block_mining_info(block)
    return if block.blank?

    miner_address = block.miner_address
    unless block.mining_infos.exists?(block_number: block.number,
                                      address: miner_address)
      block.mining_infos.create!(block_number: block.number,
                                 address: miner_address, status: "mined")
      miner_address.increment!(:mined_blocks_count)
    end
  end

  def self.normal_tx_fee(input_capacities, output_capacities)
    input_capacities - output_capacities
  end

  def self.dao_withdraw_tx_fee(ckb_transaction)
    if ckb_transaction.is_a?(CkbTransaction)
      nervos_dao_withdrawing_cells = ckb_transaction.inputs.nervos_dao_withdrawing
      interests =
        nervos_dao_withdrawing_cells.reduce(0) do |memo, nervos_dao_withdrawing_cell|
          memo + dao_interest(nervos_dao_withdrawing_cell)
        end
      ckb_transaction.inputs.sum(:capacity) + interests - ckb_transaction.outputs.sum(:capacity)
    else
      nervos_dao_withdrawing_cells = CellOutput.where(consumed_by_id: ckb_transaction["id"]).nervos_dao_withdrawing
      interests =
        nervos_dao_withdrawing_cells.reduce(0) do |memo, nervos_dao_withdrawing_cell|
          memo + dao_interest(nervos_dao_withdrawing_cell)
        end
      CellOutput.where(consumed_by_id: ckb_transaction["id"]).sum(:capacity) + interests - CellOutput.where(ckb_transaction: ckb_transaction["id"]).sum(:capacity)
    end
  end

  def self.dao_interest(nervos_dao_withdrawing_cell)
    nervos_dao_withdrawing_cell_generated_tx = nervos_dao_withdrawing_cell.ckb_transaction
    nervos_dao_deposit_cell = nervos_dao_withdrawing_cell_generated_tx.cell_inputs.order(:id)[nervos_dao_withdrawing_cell.cell_index].previous_cell_output
    withdrawing_dao_cell_block_dao = nervos_dao_withdrawing_cell.dao
    DaoCompensationCalculator.new(nervos_dao_deposit_cell, withdrawing_dao_cell_block_dao,
                                  nervos_dao_withdrawing_cell).call
  end

  # see https://github.com/nervosnetwork/rfcs/blob/master/rfcs/0027-block-structure/0027-block-structure.md#compact_target-uint32
  # @param  [Integer] 64-bit compact
  # @return [Integer] difficulty
  def self.compact_to_difficulty(compact)
    target, overflow = compact_to_target(compact)
    if target.zero? || overflow
      return 0
    end

    target_to_difficulty(target)
  end

  # parse compact_targe in block header
  # see https://github.com/nervosnetwork/rfcs/blob/master/rfcs/0027-block-structure/0027-block-structure.md#compact_target-uint32
  # @param  [Integer] 64-bit compact
  # @return [Integer] target
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

    [ret, overflow]
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

  # recursively convert value in hash to string value
  # @param [Hash] hash
  # @return [Hash] new hash with all value with string type
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

  # parse dao header in block header to dao related statistics information
  # See https://github.com/nervosnetwork/rfcs/blob/master/rfcs/0027-block-structure/0027-block-structure.md#toc13
  # @param [String] 64-bit dao header
  # @return [OpenStruct] dao related statistics information
  def self.parse_dao(dao)
    return if dao.blank?

    bin_dao = CKB::Utils.hex_to_bin(dao)
    c_i = bin_dao[0..7].unpack("Q<").pack("Q>").unpack1("H*").hex
    ar_i = bin_dao[8..15].unpack("Q<").pack("Q>").unpack1("H*").hex
    s_i = bin_dao[16..23].unpack("Q<").pack("Q>").unpack1("H*").hex
    u_i = bin_dao[24..].unpack("Q<").pack("Q>").unpack1("H*").hex

    OpenStruct.new(c_i:, ar_i:, s_i:, u_i:)
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

  def self.decode_header_deps(raw_header_deps)
    if /\A(0|\\)x/.match?(raw_header_deps)
      raw_header_deps = [raw_header_deps[2..-1]].pack("H*")
    end
    array_size = raw_header_deps.unpack1("S!")
    template = "S!#{'H64' * array_size}"
    raw_header_deps.unpack(template.to_s).drop(1).compact.map do |hash|
      "#{Settings.default_hash_prefix}#{hash}"
    end
  end

  # detect cell type from type script and cell data
  # @param [TypeScript, CKB::Types::Script] type_script
  # @param [String] output_data
  # @return [String] cell type
  def self.cell_type(type_script, output_data)
    return "normal" unless ([
      Settings.dao_code_hash, Settings.dao_type_hash, Settings.sudt_cell_type_hash, Settings.sudt1_cell_type_hash,
      CkbSync::Api.instance.issuer_script_code_hash, CkbSync::Api.instance.token_class_script_code_hash,
      CkbSync::Api.instance.token_script_code_hash, CkbSync::Api.instance.cota_registry_code_hash,
      CkbSync::Api.instance.cota_regular_code_hash, CkbSync::Api.instance.omiga_inscription_info_code_hash,
      CkbSync::Api.instance.xudt_code_hash, CkbSync::Api.instance.unique_cell_code_hash, *CkbSync::Api.instance.xudt_compatible_code_hashes, CkbSync::Api.instance.did_cell_code_hash
    ].include?(type_script&.code_hash) && type_script&.hash_type == "type") ||
      is_nrc_721_token_cell?(output_data) ||
      is_nrc_721_factory_cell?(output_data) ||
      [
        *CkbSync::Api.instance.spore_cluster_code_hashes,
        *CkbSync::Api.instance.spore_cell_code_hashes,
      ].include?(type_script&.code_hash) && type_script&.hash_type == "data1" ||
      CkbSync::Api.instance.mode == CKB::MODE::MAINNET && [CkbSync::Api.instance.xudt_code_hash,
                                                           CkbSync::Api.instance.unique_cell_code_hash].include?(type_script&.code_hash) && type_script&.hash_type == "data1"

    case type_script&.code_hash
    when Settings.dao_code_hash, Settings.dao_type_hash
      if output_data == CKB::Utils.bin_to_hex("\x00" * 8)
        "nervos_dao_deposit"
      else
        "nervos_dao_withdrawing"
      end
    when Settings.sudt_cell_type_hash, Settings.sudt1_cell_type_hash
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
    when CkbSync::Api.instance.cota_registry_code_hash
      "cota_registry"
    when CkbSync::Api.instance.cota_regular_code_hash
      "cota_regular"
    when *CkbSync::Api.instance.spore_cluster_code_hashes
      "spore_cluster"
    when *CkbSync::Api.instance.spore_cell_code_hashes
      "spore_cell"
    when CkbSync::Api.instance.did_cell_code_hash
      "did_cell"
    when CkbSync::Api.instance.omiga_inscription_info_code_hash
      "omiga_inscription_info"
    when *CkbSync::Api.instance.xudt_compatible_code_hashes
      "xudt_compatible"
    when CkbSync::Api.instance.xudt_code_hash
      Rails.cache.fetch(type_script.compute_hash) do
        if OmigaInscriptionInfo.exists?(udt_hash: type_script.compute_hash)
          "omiga_inscription"
        else
          "xudt"
        end
      end
    when CkbSync::Api.instance.unique_cell_code_hash
      "unique_cell"
    else
      if is_nrc_721_token_cell?(output_data)
        "nrc_721_token"
      elsif is_nrc_721_factory_cell?(output_data)
        "nrc_721_factory"
      else
        "normal"
      end
    end
  end

  # Parse mNFT issuer data information from cell data
  # @param [String] cell data
  # @return [OpenStruct] mNFT issuer data information
  def self.parse_issuer_data(data)
    data = data.delete_prefix("0x")
    version = data[0..1].to_i(16)
    class_count = data[2..9].to_i(16)
    set_count = data[10..17].to_i(16)
    info_size = data[18..21].to_i(16)
    info = JSON.parse(
      [data[22..]].pack("H*").force_encoding("UTF-8").encode("UTF-8", invalid: :replace,
                                                                      undef: :replace).delete("\u0000"),
    )
    OpenStruct.new(version:, class_count:,
                   set_count:, info_size:, info:)
  rescue StandardError
    OpenStruct.new(version: 0, class_count: 0, set_count: 0, info_size: 0,
                   info: "")
  end

  # Parse mNFT token class data information from cell data
  # @param [String] cell data
  # @return [OpenStruct] mNFT token class data information
  def self.parse_token_class_data(data)
    data = data.delete_prefix("0x")
    version = data[0..1].to_i(16)
    total = data[2..9].to_i(16)
    issued = data[10..17].to_i(16)
    configure = data[18..19].to_i(16)
    name_size = data[20..23].to_i(16)
    name_end_index = (24 + name_size * 2 - 1)
    name = [data[24..name_end_index]].pack("H*").force_encoding("UTF-8").encode("UTF-8", invalid: :replace,
                                                                                         undef: :replace).delete("\u0000")
    description_size_start_index = name_end_index + 1
    description_size_end_index = description_size_start_index + 4 - 1
    description_size = data[description_size_start_index..description_size_end_index].to_i(16)
    description_start_index = description_size_end_index + 1
    description_end_index = description_start_index + description_size * 2 - 1
    description = [data[description_start_index..description_end_index]].pack("H*").force_encoding("UTF-8").encode(
      "UTF-8", invalid: :replace, undef: :replace
    ).delete("\u0000")
    renderer_size_start_index = description_end_index + 1
    renderer_size_end_index = renderer_size_start_index + 4 - 1
    renderer_size = data[renderer_size_start_index..renderer_size_end_index].to_i(16)
    renderer_start_index = renderer_size_end_index + 1
    renderer_end_index = renderer_start_index + renderer_size * 2 - 1
    renderer = [data[renderer_start_index, renderer_end_index]].pack("H*").force_encoding("UTF-8").encode("UTF-8",
                                                                                                          invalid: :replace, undef: :replace).delete("\u0000")
    OpenStruct.new(version:, total:, issued:, configure:, name:,
                   description:, renderer:)
  rescue StandardError
    OpenStruct.new(version: 0, total: 0, issued: 0, configure: 0, name: "",
                   description: "", renderer: "")
  end

  def self.generate_crc32(str)
    crc = Digest::CRC32.new
    crc.update(str).checksum
  end

  def self.is_nrc_721_token_cell?(output_data)
    output_data.start_with?(Settings.nrc_721_token_output_data_header)
  end

  def self.is_nrc_721_factory_cell?(output_data)
    output_data.start_with?(Settings.nrc_721_factory_output_data_header)
  end

  def self.parse_nrc_721_args(args)
    args = args.delete_prefix("0x")
    factory_code_hash = "0x#{args[0..63]}"
    factory_type = args[64..65] == "01" ? "type" : "data"
    factory_args = "0x#{args[66..129]}"
    factory_token_id = args[130..-1]
    OpenStruct.new(code_hash: factory_code_hash, hash_type: factory_type, args: factory_args,
                   token_id: factory_token_id)
  end

  def self.parse_nrc_721_factory_data(data)
    data = data.delete_prefix(Settings.nrc_721_factory_output_data_header)
    arg_name_length = 4
    name_byte_size = data[0, arg_name_length].to_i(16)
    factory_name_hex = data[arg_name_length, name_byte_size * 2]

    arg_symbol_length = 4
    symbol_byte_size = data[(factory_name_hex.length + arg_name_length),
                            arg_symbol_length].to_i(16)
    factory_symbol_hex = data[arg_name_length + factory_name_hex.length + arg_symbol_length,
                              symbol_byte_size * 2]

    arg_base_token_uri_length = 4
    base_token_uri_length = data[(arg_name_length + factory_name_hex.length + arg_symbol_length + factory_symbol_hex.length),
                                 arg_base_token_uri_length].to_i(16)
    factory_base_token_uri_hex = data[(arg_name_length + factory_name_hex.length + arg_symbol_length + factory_symbol_hex.length + arg_base_token_uri_length),
                                      base_token_uri_length * 2]
    extra_data_hex = data[(arg_name_length + factory_name_hex.length + arg_symbol_length + factory_symbol_hex.length + arg_base_token_uri_length + base_token_uri_length * 2)..-1]
    OpenStruct.new(name: [factory_name_hex].pack("H*"), symbol: [factory_symbol_hex].pack("H*"),
                   base_token_uri: [factory_base_token_uri_hex].pack("H*"), extra_data: extra_data_hex)
  end

  # comes from api/v2/base_controller.rb
  # convert a address hash to lock hash
  # if the address is started with 0x, then this is a lock hash and directly return it
  # @param [String] address
  # @return [String] lock hash
  def self.address_to_lock_hash(address)
    if address.start_with?("0x")
      address
    else
      parsed = CkbUtils.parse_address(address)
      parsed.script.compute_hash
    end
  end

  def self.hex_since(int_since_value)
    "0x#{int_since_value.to_s(16).rjust(16, '0')}"
  end

  def self.shannon_to_byte(shannon)
    shannon / (10**8)
  end

  def self.hexes_to_bins_sql(hex_strings)
    if hex_strings.is_a?(Array) && hex_strings.length > 0
      hex_strings.map do |hex_string|
        ActiveRecord::Base.sanitize_sql_array(["E'\\\\x%s'::bytea",
                                               hex_string.delete_prefix("0x")])
      end.join(", ")
    else
      []
    end
  end

  def self.parse_spore_cluster_data(hex_data)
    data = hex_data.slice(2..-1)
    name_offset = [data.slice(8, 8)].pack("H*").unpack1("l") * 2
    description_offset = [data.slice(16, 8)].pack("H*").unpack1("l") * 2
    name = [data.slice(name_offset + 8..description_offset - 1)].pack("H*")
    description = [data.slice(description_offset + 8..-1)].pack("H*")
    name = "#{name[0, 97]}..." if name.length > 100

    { name: sanitize_string(name), description: sanitize_string(description) }
  rescue StandardError => e
    puts "Error parsing spore cluster data: #{e.message}"
    { name: nil, description: nil }
  end

  def self.parse_spore_cell_data(hex_data)
    data = hex_data.slice(2..-1)
    content_type_offset = [data.slice(8, 8)].pack("H*").unpack1("l") * 2
    content_offset = [data.slice(16, 8)].pack("H*").unpack1("l") * 2
    cluster_id_offset = [data.slice(24, 8)].pack("H*").unpack1("l") * 2
    content_type = [data.slice(content_type_offset + 8..content_offset - 1)].pack("H*")
    content = data.slice(content_offset + 8..cluster_id_offset - 1)
    cluster_id = data.slice(cluster_id_offset + 8..-1)
    { content_type:, content:,
      cluster_id: cluster_id.nil? ? nil : "0x#{cluster_id}" }
  rescue StandardError => _e
    { content_type: nil, content: nil, cluster_id: nil }
  end

  def self.parse_omiga_inscription_info(hex_data)
    data = hex_data.delete_prefix("0x")
    decimal = "0x#{data.slice!(0, 2)}".to_i(16)
    name_len = "0x#{data.slice!(0, 2)}".to_i(16)
    name = [data.slice!(0, name_len * 2)].pack("H*")
    symbol_len = "0x#{data.slice!(0, 2)}".to_i(16)
    symbol = [data.slice!(0, symbol_len * 2)].pack("H*")
    udt_hash = "0x#{data.slice!(0, 64)}"
    expected_supply = [data.slice!(0, 32)].pack("H*").bytes.reverse.pack("C*").unpack1("H*").hex
    mint_limit = [data.slice!(0, 32)].pack("H*").bytes.reverse.pack("C*").unpack1("H*").hex
    mint_status = "0x#{data.slice!(0, 2)}".to_i(16)
    { decimal:, name: name.presence, symbol: symbol.presence, udt_hash:, expected_supply:,
      mint_limit:, mint_status: }
  end

  def self.parse_omiga_inscription_data(hex_data)
    data = hex_data.delete_prefix("0x")
    mint_limit = [data].pack("H*").bytes.reverse.pack("C*").unpack1("H*").hex
    { mint_limit: }
  end

  def self.is_rgbpp_lock_cell?(lock_script)
    CkbSync::Api.instance.rgbpp_code_hash.include?(lock_script.code_hash) && lock_script.hash_type == "type"
  end

  def self.is_btc_time_lock_cell?(lock_script)
    CkbSync::Api.instance.btc_time_code_hash.include?(lock_script.code_hash) && lock_script.hash_type == "type"
  end

  def self.parse_btc_time_lock_cell(args)
    args_serialization = [args.delete_prefix("0x")].pack("H*")
    script_offset = [args_serialization[4..7].unpack1("H*")].pack("H*").unpack1("V")
    after_offset = [args_serialization[8..11].unpack1("H*")].pack("H*").unpack1("V")
    txid_offset = [args_serialization[12..15].unpack1("H*")].pack("H*").unpack1("V")

    script_serialization = args_serialization[script_offset...after_offset]
    code_hash_offset = [script_serialization[4..7].unpack1("H*")].pack("H*").unpack1("V")
    hash_type_offset = [script_serialization[8..11].unpack1("H*")].pack("H*").unpack1("V")
    args_offset = [script_serialization[12..15].unpack1("H*")].pack("H*").unpack1("V")
    script_code_hash_serialization = script_serialization[code_hash_offset...hash_type_offset]
    script_hash_type_serialization = script_serialization[hash_type_offset...args_offset]
    script_args_serialization = script_serialization[hash_type_offset + 1..]
    code_hash = "0x#{script_code_hash_serialization.unpack1('H*')}"
    hash_type_hex = "0x#{script_hash_type_serialization.unpack1('H*')}"
    hash_type = hash_type_hex == "0x00" ? "data" : "type"
    args = "0x#{script_args_serialization.unpack1('H*')}"
    lock = CKB::Types::Script.new(code_hash:, args:, hash_type:)

    after_serialization = args_serialization[after_offset...txid_offset]
    after = [after_serialization.unpack1("H*")].pack("H*").unpack1("V")

    txid_serialization = args_serialization[txid_offset..]
    txid = txid_serialization.unpack1("H*").scan(/../).reverse.join

    OpenStruct.new(lock:, after:, txid:)
  end

  # * https://learnmeabitcoin.com/technical/general/byte-order/
  # Whenever you're working with transaction/block hashes internally (e.g. inside raw bitcoin data), you use the natural byte order.
  # Whenever you're displaying or searching for transaction/block hashes, you use the reverse byte order.
  def self.parse_rgbpp_args(args)
    args = args.delete_prefix("0x")
    out_index = [args[0..7]].pack("H*").unpack1("v")
    txid = args[8..-1].scan(/../).reverse.join

    [txid, out_index]
  end

  # https://github.com/ckb-cell/rgbpp-sdk/blob/develop/packages/ckb/src/utils/rgbpp.ts
  def self.calculate_commitment(transaction)
    inputs = transaction.input_cells.select { _1.type_script.present? }
    outputs = transaction.cell_outputs.select { _1.type_script.present? }

    hash = Digest::SHA256.new
    hash.update("RGB++")
    version = [0, 0].pack("C*")
    hash.update(version)

    if inputs.length > MAX_RGBPP_CELL_NUM || outputs.length > MAX_RGBPP_CELL_NUM
      raise ArgumentError, "The inputs or outputs length of RGB++ CKB virtual tx cannot be greater than 255"
    end

    hash.update([inputs.length, outputs.length].pack("C*"))

    inputs.each do |input|
      out_point = CKB::Types::OutPoint.new(tx_hash: input.tx_hash, index: input.cell_index)
      binary_out_point = CKB::Utils.hex_to_bin(CKB::Serializers::OutPointSerializer.new(out_point).serialize)
      hash.update(binary_out_point.bytes.pack("C*"))
    end

    outputs.each do |output|
      # Before a Bitcoin transaction is confirmed on the blockchain, its transaction ID (txid) is uncertain.
      # Therefore, when passing parameters to `calculateCommitment`, manually replace the txid part in the lock args with "0x01000....0000".
      new_output = CKB::Types::Output.from_h(output.to_raw)
      new_output.lock.args = new_output.lock.args.slice(0, 10) + "0" * 64

      binary_output = CKB::Utils.hex_to_bin(CKB::Serializers::OutputSerializer.new(new_output).serialize)
      hash.update(binary_output.bytes.pack("C*"))

      output_data = output.data
      output_data_serializer = CKB::Serializers::OutputDataSerializer.new(output_data)
      output_data_length = output_data_serializer.as_json["items_count"]
      binary_output_data_length = CKB::Utils.hex_to_bin("0x#{[output_data_length].pack('V').unpack1('H*')}")
      hash.update(binary_output_data_length.bytes.pack("C*"))

      binary_output_data = CKB::Utils.hex_to_bin(output_data).bytes.pack("C*")
      hash.update(binary_output_data.bytes.pack("C*"))
    end

    Digest::SHA256.hexdigest(hash.digest.bytes.pack("C*"))
  end

  def self.parse_unique_cell(hex_data)
    data = hex_data.delete_prefix("0x")
    decimal = "0x#{data.slice!(0, 2)}".to_i(16)
    name_len = "0x#{data.slice!(0, 2)}".to_i(16)
    name = [data.slice!(0, name_len * 2)].pack("H*")
    symbol_len = "0x#{data.slice!(0, 2)}".to_i(16)
    symbol = [data.slice!(0, symbol_len * 2)].pack("H*")
    { decimal:, name: name.presence, symbol: symbol.presence }
  end

  def self.sanitize_string(str)
    str.force_encoding("UTF-8").encode("UTF-8", invalid: :replace, undef: :replace, replace: "").gsub(/[[:cntrl:]\u2028\u2029\u200B]/, "")
  rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError
    ""
  end
end
