class AddIndexToCkbTransactions < ActiveRecord::Migration[7.0]
  def change
    add_index :ckb_transactions, :block_number
    add_index :ckb_transactions, :block_timestamp
    add_index :ckb_transactions, :transaction_fee
  end
end
