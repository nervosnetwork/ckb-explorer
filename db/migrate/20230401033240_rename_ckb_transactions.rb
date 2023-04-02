class RenameCkbTransactions < ActiveRecord::Migration[7.0]
  def change
    rename_table :ckb_transactions, :old_ckb_transactions
    rename_table :partitioned_ckb_transactions, :ckb_transactions
  end
end
