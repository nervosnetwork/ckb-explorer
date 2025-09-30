class RemoveTotalDepositorsCountFromDao < ActiveRecord::Migration[7.0]
  def change
    remove_columns :dao_contracts, :total_depositors_count, type: :bigint
    remove_columns :dao_contracts, :deposit_transactions_count, type: :bigint
    remove_columns :dao_contracts, :withdraw_transactions_count, type: :bigint
    remove_columns :dao_contracts, :ckb_transactions_count, type: :bigint
  end
end
