module CkbSync
  class NodeDataProcessor
    def call
      local_tip_block = Block.recent.first
      target_block_number = local_tip_block.present? ? local_tip_block.number + 1 : 0
      target_block = CkbSync::Api.instance.get_block_by_number(target_block_number)
      return if target_block.blank?

      if !forked?(target_block, local_tip_block)
        process_block(target_block)
      else
        invalid_block(local_tip_block)
      end
    end

    def process_block(node_block)
      local_block = build_block(node_block)

      node_block.uncles.each do |uncle_block|
        build_uncle_block(uncle_block, local_block)
      end

      ApplicationRecord.transaction do
        ckb_transactions = build_ckb_transactions(local_block, node_block.transactions)
        local_block.ckb_transactions_count = ckb_transactions.size
        local_block.save!
      end

      update_tx_fee_related_data(local_block)
      calculate_tx_fee(local_block)

      update_miner_pending_rewards(local_block.miner_address)
      update_block_contained_address_info(local_block)
      update_block_reward_info(local_block)

      local_block
    end

    private

    def update_block_reward_info(current_block)
      target_block_number = current_block.target_block_number
      target_block = current_block.target_block
      return if target_block_number < 1 || target_block.blank?

      ApplicationRecord.transaction do
        issue_block_reward!(current_block)
        CkbUtils.update_target_block_miner_address_pending_rewards(current_block)
      end
    end

    def issue_block_reward!(current_block)
      CkbUtils.update_block_reward_status!(current_block)
      CkbUtils.calculate_received_tx_fee!(current_block)
    end

    def revert_block_rewards(local_tip_block)
      revert_miner_pending_reward_blocks_count(local_tip_block)
      target_block = local_tip_block.target_block
      target_block_number = local_tip_block.target_block_number
      return if target_block_number < 1 || target_block.blank?

      revert_reward_status(local_tip_block, target_block)
      revert_received_tx_fee(target_block)
    end

    def revert_received_tx_fee(target_block)
      target_block.update!(received_tx_fee: 0)
    end

    def revert_reward_status(local_tip_block, target_block)
      target_block.update!(reward_status: "pending")
      local_tip_block.update!(target_block_reward_status: "pending")
      target_block.update!(received_tx_fee_status: "calculating")
    end

    def revert_miner_pending_reward_blocks_count(local_tip_block)
      miner_address = local_tip_block.miner_address
      Address.decrement_counter(:pending_reward_blocks_count, miner_address.id, touch: true) if miner_address.present?
    end

    def invalid_block(local_tip_block)
      ApplicationRecord.transaction do
        local_tip_block.invalid!
        local_tip_block.contained_addresses.each(&method(:update_address_balance_and_ckb_transactions_count))
        revert_block_rewards(local_tip_block)

        local_tip_block
      end
    end

    def update_block_contained_address_info(local_block)
      ApplicationRecord.transaction do
        local_block.address_ids = AccountBook.where(ckb_transaction: local_block.ckb_transactions).pluck(:address_id).uniq
        local_block.save!
        local_block.contained_addresses.each(&method(:update_address_balance_and_ckb_transactions_count))
      end
    end

    def forked?(target_block, local_tip_block)
      return false if local_tip_block.blank?

      target_block.header.parent_hash != local_tip_block.block_hash
    end

    def uncle_block_hashes(node_block_uncles)
      node_block_uncles.map { |uncle| uncle.header.hash }
    end

    def generate_address_in_advance(cellbase)
      return if cellbase.witnesses.blank?

      lock_script = CkbUtils.generate_lock_script_from_cellbase(cellbase)
      address = Address.find_or_create_address(lock_script)
      LockScript.find_or_create_by(
        args: lock_script.args,
        code_hash: lock_script.code_hash,
        address: address
      )
    end

    def build_block(node_block)
      header = node_block.header
      epoch_info = CkbUtils.get_epoch_info(header.epoch)
      cellbase = node_block.transactions.first

      generate_address_in_advance(cellbase)

      Block.new(
        difficulty: header.difficulty,
        block_hash: header.hash,
        number: header.number,
        parent_hash: header.parent_hash,
        seal: header.seal,
        timestamp: header.timestamp,
        transactions_root: header.transactions_root,
        proposals_hash: header.proposals_hash,
        uncles_count: header.uncles_count,
        uncles_hash: header.uncles_hash,
        uncle_block_hashes: uncle_block_hashes(node_block.uncles),
        version: header.version,
        proposals: node_block.proposals,
        proposals_count: node_block.proposals.count,
        cell_consumed: CkbUtils.block_cell_consumed(node_block.transactions),
        total_cell_capacity: CkbUtils.total_cell_capacity(node_block.transactions),
        miner_hash: CkbUtils.miner_hash(cellbase),
        miner_lock_hash: CkbUtils.miner_lock_hash(cellbase),
        reward: CkbUtils.block_reward(node_block),
        reward_status: header.number.to_i == 0 ? "issued" : "pending",
        total_transaction_fee: 0,
        witnesses_root: header.witnesses_root,
        epoch: header.epoch,
        start_number: epoch_info.start_number,
        length: epoch_info.length,
        dao: header.dao
      )
    end

    def build_uncle_block(uncle_block, local_block)
      header = uncle_block.header
      local_block.uncle_blocks.build(
        difficulty: header.difficulty,
        block_hash: header.hash,
        number: header.number,
        parent_hash: header.parent_hash,
        seal: header.seal,
        timestamp: header.timestamp,
        transactions_root: header.transactions_root,
        proposals_hash: header.proposals_hash,
        uncles_count: header.uncles_count,
        uncles_hash: header.uncles_hash,
        version: header.version,
        proposals: uncle_block.proposals,
        proposals_count: uncle_block.proposals.count,
        witnesses_root: header.witnesses_root,
        epoch: header.epoch,
        dao: header.dao
      )
    end

    def build_ckb_transactions(local_block, transactions)
      transactions.each_with_index.map do |transaction, transaction_index|
        addresses = Set.new
        ckb_transaction = build_ckb_transaction(local_block, transaction, transaction_index)
        build_cell_inputs(transaction.inputs, ckb_transaction)
        build_cell_outputs(transaction.outputs, ckb_transaction, addresses, transaction.outputs_data)
        addresses_arr = addresses.to_a
        ckb_transaction.addresses << addresses_arr

        ckb_transaction
      end
    end

    def build_ckb_transaction(local_block, transaction, transaction_index)
      local_block.ckb_transactions.build(
        tx_hash: transaction.hash,
        cell_deps: transaction.cell_deps,
        header_deps: transaction.header_deps,
        version: transaction.version,
        block_number: local_block.number,
        block_timestamp: local_block.timestamp,
        transaction_fee: 0,
        witnesses: transaction.witnesses.map(&:to_h),
        is_cellbase: transaction_index.zero?
      )
    end

    def build_cell_inputs(node_inputs, ckb_transaction)
      node_inputs.each do |node_input|
        build_cell_input(ckb_transaction, node_input)
      end
    end

    def build_cell_input(ckb_transaction, node_input)
      ckb_transaction.cell_inputs.build(
        previous_output: node_input.previous_output,
        since: node_input.since,
        block: ckb_transaction.block,
        from_cell_base: from_cell_base?(node_input)
      )
    end

    def from_cell_base?(node_input)
      node_input.previous_output.tx_hash == CellOutput::SYSTEM_TX_HASH
    end

    def build_cell_outputs(node_outputs, ckb_transaction, addresses, outputs_data)
      node_outputs.each_with_index.map do |output, cell_index|
        address = Address.find_or_create_address(output.lock)
        addresses << address
        cell_output = build_cell_output(ckb_transaction, output, address, cell_index, outputs_data[cell_index])
        build_lock_script(cell_output, output.lock, address)
        build_type_script(cell_output, output.type)

        cell_output
      end
    end

    def cell_type(type_script)
      return "normal" if type_script.blank?

      type_script.code_hash == ENV["DAO_CODE_HASH"] ? "dao" : "normal"
    end

    def build_cell_output(ckb_transaction, output, address, cell_index, output_data)
      ckb_transaction.cell_outputs.build(
        capacity: output.capacity,
        data: output_data,
        address: address,
        block: ckb_transaction.block,
        tx_hash: ckb_transaction.tx_hash,
        cell_index: cell_index,
        generated_by: ckb_transaction,
        cell_type: cell_type(output.type)
      )
    end

    def build_lock_script(cell_output, lock_script, address)
      cell_output.build_lock_script(
        args: lock_script.args,
        code_hash: lock_script.code_hash,
        address: address,
        hash_type: lock_script.hash_type
      )
    end

    def build_type_script(cell_output, type_script)
      return if type_script.blank?

      cell_output.build_type_script(
        args: type_script.args,
        code_hash: type_script.code_hash,
        hash_type: type_script.hash_type
      )
    end

    def update_tx_fee_related_data(lock_block)
      ApplicationRecord.transaction do
        lock_block.cell_inputs.where(from_cell_base: false, previous_cell_output_id: nil).find_each do |cell_input|
          ckb_transaction = cell_input.ckb_transaction
          previous_cell_output = cell_input.previous_cell_output
          address = previous_cell_output.address

          link_previous_cell_output_to_cell_input(cell_input, previous_cell_output)
          link_payer_address_to_ckb_transaction(ckb_transaction, address)

          update_previous_cell_output_status(ckb_transaction, previous_cell_output)
        end
      end
    end

    def link_previous_cell_output_to_cell_input(cell_input, previous_cell_output)
      cell_input.update!(previous_cell_output_id: previous_cell_output.id)
    end

    def link_payer_address_to_ckb_transaction(ckb_transaction, address)
      ckb_transaction.addresses << address
    end

    def update_previous_cell_output_status(ckb_transaction, previous_cell_output)
      previous_cell_output.update!(consumed_by: ckb_transaction, status: :dead)
    end

    def update_address_balance_and_ckb_transactions_count(address)
      address.balance = address.cell_outputs.live.sum(:capacity)
      address.ckb_transactions_count = address.ckb_transactions.distinct.count
      address.save!
    end

    def calculate_tx_fee(local_block)
      ckb_transactions = local_block.ckb_transactions.where(is_cellbase: false)
      return if ckb_transactions.blank?

      ApplicationRecord.transaction do
        ckb_transactions.each(&method(:update_transaction_fee))
        local_block.total_transaction_fee = local_block.ckb_transactions.sum(:transaction_fee)
        local_block.save!
      end
    end

    def update_transaction_fee(ckb_transaction)
      transaction_fee = CkbUtils.ckb_transaction_fee(ckb_transaction)
      ckb_transaction.transaction_fee = transaction_fee
      ckb_transaction.save!
    end

    def update_miner_pending_rewards(miner_address)
      CkbUtils.update_current_block_miner_address_pending_rewards(miner_address)
    end
  end
end
