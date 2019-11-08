class LockHashSerializer
  include FastJsonapi::ObjectSerializer

  set_type :lock_hash

  attributes :address_hash, :lock_hash

  attribute :lock_script do |object|
    object.lock_script.to_node_lock
  end

  attribute :transactions_count do |object|
    object.ckb_transactions_count.to_s
  end

  attribute :balance do |object|
    object.balance.to_s
  end
  attribute :dao_deposit do |object|
    object.dao_deposit.to_s
  end
  attribute :interest do |object|
    object.interest.to_s
  end
end
