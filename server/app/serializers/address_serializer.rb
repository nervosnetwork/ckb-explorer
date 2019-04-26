class AddressSerializer
  include FastJsonapi::ObjectSerializer

  attributes :address_hash

  attribute :transactions_count do |object|
    object.ckb_transactions_count
  end

  attribute :lock_script do |object|
    object.lock_script.to_node_lock
  end

  attribute :balance do |object|
    Shannon.new(object.balance).to_ckb
  end

  attribute :cell_consumed do |object|
    Shannon.new(object.cell_consumed).to_ckb
  end
end
