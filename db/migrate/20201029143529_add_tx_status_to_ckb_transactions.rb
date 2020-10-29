class AddTxStatusToCkbTransactions < ActiveRecord::Migration[6.0]
  def change
    add_column :ckb_transactions, :tx_status, :integer, default: 0
  end
end
