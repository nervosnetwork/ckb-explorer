class CreateScriptTransactions < ActiveRecord::Migration[7.0]
  def change
    create_table :script_transactions do |t|
      t.bigint :script_id
      t.bigint :ckb_transaction_id

      t.timestamps null:false
    end

    add_index :script_transactions, :script_id
    add_index :script_transactions, :ckb_transaction_id
  end
end
