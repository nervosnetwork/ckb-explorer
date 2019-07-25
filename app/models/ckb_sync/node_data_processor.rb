module CkbSync
  class NodeDataProcessor
    def call(node_block)
      local_block = build_block(node_block)

      node_block.uncles.each do |uncle_block|
        build_uncle_block(uncle_block, local_block)
      end

      ckb_transactions = build_ckb_transactions(local_block, node_block.transactions)
      local_block.ckb_transactions_count = ckb_transactions.size
      local_block.save

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
        ckb_transaction = build_ckb_transaction(local_block, transaction, transaction_index)
        build_cell_inputs(transaction.inputs, ckb_transaction)
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
  end
end
