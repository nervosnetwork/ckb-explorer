class BlockSerializer
  include FastJsonapi::ObjectSerializer

  attributes :block_hash, :number, :proposals_count, :uncles_count, :uncle_block_hashes, :reward, :total_transaction_fee, :cell_consumed, :total_cell_capacity, :miner_hash, :timestamp, :difficulty, :version, :epoch, :start_number, :length, :transactions_root, :witnesses_root

  attribute :nonce do |object|
    object.seal["nonce"]
  end

  attribute :proof do |object|
    object.seal["proof"]
  end

  attribute :transactions_count, &:ckb_transactions_count
end
