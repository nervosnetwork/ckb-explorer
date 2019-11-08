class DaoContractSerializer
  include FastJsonapi::ObjectSerializer
  set_type :dao
  attributes :total_deposit, :interest_granted, :deposit_transactions_count, :withdraw_transactions_count,
             :depositors_count, :total_depositors_count
  attribute :dao_type_hash do
    ENV["DAO_TYPE_HASH"]
  end
end
