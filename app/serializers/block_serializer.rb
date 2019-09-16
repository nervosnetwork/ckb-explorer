class BlockSerializer
  include FastJsonapi::ObjectSerializer

  attributes :block_hash, :number, :proposals_count, :uncles_count, :uncle_block_hashes, :reward,
             :total_transaction_fee, :cell_consumed, :total_cell_capacity, :miner_hash, :timestamp,
             :difficulty, :version, :epoch, :start_number, :length, :transactions_root, :witnesses_root, :reward_status,
             :received_tx_fee, :received_tx_fee_status, :nonce, :chain_root

  attribute :transactions_count, &:ckb_transactions_count
end
