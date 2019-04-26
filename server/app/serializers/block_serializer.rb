class BlockSerializer
  include FastJsonapi::ObjectSerializer

  attributes :block_hash, :number, :proposal_transactions_count, :uncles_count, :uncle_block_hashes, :miner_hash, :timestamp, :difficulty, :version

  attribute :nonce do |object|
    object.seal["nonce"]
  end

  attribute :proof do |object|
    object.seal["proof"]
  end

  attribute :transactions_count do |object|
    object.ckb_transactions_count
  end

  attribute :reward do |object|
    Shannon.new(object.reward).to_ckb
  end
  attribute :total_transaction_fee do |object|
    Shannon.new(object.total_transaction_fee).to_ckb
  end
  attribute :cell_consumed do |object|
    Shannon.new(object.cell_consumed).to_ckb
  end
  attribute :total_cell_capacity do |object|
    Shannon.new(object.total_cell_capacity).to_ckb
  end
end
