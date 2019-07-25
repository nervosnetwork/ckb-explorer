module CkbSync
  class NodeDataProcessor
    def call(node_block)
      local_block = build_block(node_block)
      local_block.save

      local_block
    end

    private

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
  end
end
