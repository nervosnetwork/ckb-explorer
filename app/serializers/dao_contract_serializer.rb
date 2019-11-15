class DaoContractSerializer
  include FastJsonapi::ObjectSerializer
  set_type :nervos_dao
  attribute :dao_type_hash do
    ENV["DAO_TYPE_HASH"]
  end
  attribute :total_deposit do |object|
    object.total_deposit.to_s
  end
  attribute :interest_granted do |object|
    object.interest_granted.to_s
  end
  attribute :deposit_transactions_count do |object|
    object.deposit_transactions_count.to_s
  end
  attribute :withdraw_transactions_count do |object|
    object.withdraw_transactions_count.to_s
  end
  attribute :depositors_count do |object|
    object.depositors_count.to_s
  end
  attribute :total_depositors_count do |object|
    object.total_depositors_count.to_s
  end
end
