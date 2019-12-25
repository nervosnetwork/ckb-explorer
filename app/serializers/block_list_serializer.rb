class BlockListSerializer
  include FastJsonapi::ObjectSerializer

  attributes :miner_hash

  attribute :number do |object|
    object.number.to_s
  end
  attribute :timestamp do |object|
    object.timestamp.to_s
  end
  attribute :reward do |object|
    object.reward.to_s
  end
  attribute :transactions_count do |object|
    object.ckb_transactions_count.to_s
  end
end
