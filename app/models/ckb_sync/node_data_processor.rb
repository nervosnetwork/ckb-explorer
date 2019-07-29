module CkbSync
  class NodeDataProcessor
    def call(node_block)
      local_block = build_block(node_block)

      node_block.uncles.each do |uncle_block|
        build_uncle_block(uncle_block, local_block)
      end

      ApplicationRecord.transaction do
        ckb_transactions = build_ckb_transactions(local_block, node_block.transactions)
        local_block.ckb_transactions_count = ckb_transactions.size
        local_block.save
      end

      update_tx_fee_related_data(local_block)
      calculate_tx_fee(local_block)

      local_block
    end

    private

    def uncle_block_hashes(node_block_uncles)
      node_block_uncles.map { |uncle| uncle.to_h.dig("header", "hash") }
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
        status: "accepted",
        reward: CkbUtils.base_reward(header.number, header.epoch, node_block.transactions.first),
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
      transaction_index = 0
      transactions.map do |transaction|
        addresses = Set.new
        ckb_transaction = build_ckb_transaction(local_block, transaction, transaction_index)
        build_cell_inputs(transaction.inputs, ckb_transaction)
        build_cell_outputs(transaction.outputs, ckb_transaction, addresses)
        addresses_arr = addresses.to_a
        ckb_transaction.addresses << addresses_arr
        transaction_index += 1

        ckb_transaction
      end
    end

    def build_ckb_transaction(local_block, transaction, transaction_index)
      local_block.ckb_transactions.build(
        tx_hash: transaction.hash,
        deps: transaction.deps,
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
      cell = node_input.previous_output.cell

      ckb_transaction.cell_inputs.build(
        previous_output: node_input.previous_output,
        since: node_input.since,
        block: ckb_transaction.block,
        from_cell_base: cell.blank?
      )
    end

    def build_cell_outputs(node_outputs, ckb_transaction, addresses)
      cell_index = 0
      node_outputs.map do |output|
        address = Address.find_or_create_address(output.lock)
        addresses << address
        cell_output = build_cell_output(ckb_transaction, output, address, cell_index)
        build_lock_script(cell_output, output.lock, address)
        build_type_script(cell_output, output.type)
        cell_index += 1

        cell_output
      end
    end

    def build_cell_output(ckb_transaction, output, address, cell_index)
      ckb_transaction.cell_outputs.build(
        capacity: output.capacity,
        data: output.data,
        address: address,
        block: ckb_transaction.block,
        tx_hash: ckb_transaction.tx_hash,
        cell_index: cell_index,
        generated_by: ckb_transaction
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
          update_address_balance_and_ckb_transactions_count(address)
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
      address.ckb_transactions_count = address.ckb_transactions.available.distinct.count
      address.save!
    end

    def calculate_tx_fee(local_block)
      ckb_transactions = local_block.ckb_transactions.where(is_cellbase: false)

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
  end
end
