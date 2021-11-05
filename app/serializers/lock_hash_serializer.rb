class LockHashSerializer
  include FastJsonapi::ObjectSerializer

  set_type :lock_hash

  attributes :address_hash, :lock_hash

  attribute :lock_info do |object|
    object.lock_script.lock_info
  end
  attribute :lock_script do |object|
    object.lock_script.to_node_lock
  end
  attribute :balance do |object|
    object.balance.to_s
  end
  attribute :transactions_count do |object|
    object.ckb_transactions_count.to_s
  end
  attribute :dao_deposit do |object|
    object.dao_deposit.to_s
  end
  attribute :interest do |object|
    object.interest.to_s
  end
  attribute :is_special do |object|
    object.special?.to_s
  end
  attribute :special_address, if: Proc.new { |record| record.special? } do |object|
    Settings.special_addresses[object.address_hash]
  end
  attribute :live_cells_count do |object|
    object.live_cells_count.to_s
  end
  attribute :mined_blocks_count do |object|
    object.mined_blocks_count.to_s
  end
  attribute :balance_occupied do |object|
    object.balance_occupied.to_s
  end
end
