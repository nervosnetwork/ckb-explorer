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
    return if cellbase.witnesses.blank?

    lock_script = generate_lock_script_from_cellbase(cellbase)

    generate_address(lock_script)
  end

  def self.miner_lock_hash(cellbase)
    return if cellbase.witnesses.blank?

    lock_script = generate_lock_script_from_cellbase(cellbase)
    lock_script.to_hash
  end

  def self.generate_lock_script_from_cellbase(cellbase)
    witnesses_data = cellbase.witnesses.first.data
    CKB::Types::Script.new(code_hash: witnesses_data.first, args: [witnesses_data.last])
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

  def self.base_reward(block_number, epoch_number, cellbase = nil)
    return cellbase.outputs.first.capacity if block_number.to_i == 0

    epoch_info = get_epoch_info(epoch_number)
    start_number = epoch_info.start_number.to_i
    epoch_reward = epoch_info.epoch_reward.to_i
    block_reward = epoch_reward / epoch_info.length.to_i
    remainder_reward = epoch_reward % epoch_info.length.to_i
    if block_number.to_i >= start_number && block_number.to_i < start_number + remainder_reward
      block_reward + 1
    else
      block_reward
    end
  end

  def self.get_epoch_info(epoch)
    Rails.cache.fetch("epoch_#{epoch}", expires_in: 1.day) do
      CkbSync::Api.instance.get_epoch_by_number(epoch)
    end
  end

  def self.ckb_transaction_fee(ckb_transaction)
    ckb_transaction.inputs.available.sum(:capacity) - ckb_transaction.outputs.available.sum(:capacity)
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

  def self.update_block_reward_status!(current_block)
    target_block_number = current_block.target_block_number
    target_block = current_block.target_block
    return if target_block_number < 1 || target_block.blank?

    target_block.update!(reward_status: "issued")
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

  def self.update_current_block_miner_address_pending_rewards(miner_address)
    Address.increment_counter(:pending_reward_blocks_count, miner_address.id, touch: true) if miner_address.present?
  end

  def self.update_target_block_miner_address_pending_rewards(current_block)
    target_block_number = current_block.target_block_number
    target_block = current_block.target_block
    return if target_block_number < 1 || target_block.blank?

    miner_address = target_block.miner_address
    Address.decrement_counter(:pending_reward_blocks_count, miner_address.id, touch: true) if miner_address.present?
  end
end
