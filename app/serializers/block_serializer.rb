class BlockSerializer
  include FastJsonapi::ObjectSerializer

  attributes :block_hash, :uncle_block_hashes, :miner_hash, :transactions_root,
             :reward_status, :received_tx_fee_status, :miner_message
  attribute :number do |object|
    object.number.to_s
  end
  attribute :start_number do |object|
    object.start_number.to_s
  end
  attribute :length do |object|
    object.length.to_s
  end
  attribute :version do |object|
    object.version.to_s
  end
  attribute :proposals_count do |object|
    object.proposals_count.to_s
  end
  attribute :uncles_count do |object|
    object.uncles_count.to_s
  end
  attribute :timestamp do |object|
    object.timestamp.to_s
  end
  attribute :reward do |object|
    object.reward.to_s
  end
  attribute :cell_consumed do |object|
    object.cell_consumed.to_s
  end
  attribute :total_transaction_fee do |object|
    object.total_transaction_fee.to_s
  end
  attribute :transactions_count do |object|
    object.ckb_transactions_count.to_s
  end
  attribute :total_cell_capacity do |object|
    object.total_cell_capacity.to_s
  end
  attribute :received_tx_fee do |object|
    object.received_tx_fee.to_s
  end
  attribute :epoch do |object|
    object.epoch.to_s
  end
  attribute :block_index_in_epoch do |object|
    object.block_index_in_epoch.to_s
  end
  attribute :nonce do |object|
    object.nonce.to_s
  end
  attribute :difficulty do |object|
    object.difficulty.to_s
  end
  attribute :miner_reward do |object|
    (object.received_tx_fee + object.reward).to_s
  end
  attribute :size do |object|
    object.block_size
  end  
end
