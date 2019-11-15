class AddressSerializer
  include FastJsonapi::ObjectSerializer

  attributes :address_hash, :lock_script, :lock_info
  attribute :balance do |object|
    object.balance.to_s
  end
  attribute :transactions_count do |object|
    object.ckb_transactions_count.to_s
  end
  attribute :pending_reward_blocks_count do |object|
    object.pending_reward_blocks_count.to_s
  end
  attribute :dao_deposit do |object|
    object.dao_deposit.to_s
  end
  attribute :interest do |object|
    object.interest.to_s
  end
end
