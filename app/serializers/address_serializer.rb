class AddressSerializer
  include FastJsonapi::ObjectSerializer

  attributes :address_hash, :balance, :cell_consumed

  attribute(:transactions_count, &:ckb_transactions_count)

  attribute :lock_script do |object|
    object.cached_lock_script
  end

  attribute :pending_reward_blocks_count do |object|
    [object.pending_reward_blocks_count, 0].max
  end
end
