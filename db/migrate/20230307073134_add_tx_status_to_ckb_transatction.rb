class AddTxStatusToCkbTransatction < ActiveRecord::Migration[7.0]
  def change
    add_column :ckb_transactions, :tx_status, :integer, default: 2, null: false
  end
end
