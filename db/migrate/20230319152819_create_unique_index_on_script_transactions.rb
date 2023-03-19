class CreateUniqueIndexOnScriptTransactions < ActiveRecord::Migration[7.0]
  def change
    add_index :script_transactions, [:ckb_transaction_id, :script_id], unique: true
    remove_column :script_transactions, :created_at
    remove_column :script_transactions, :updated_at
  end
end
