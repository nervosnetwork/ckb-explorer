class AddTxIndexToCkbTransaction < ActiveRecord::Migration[7.0]
  def change
    add_column :ckb_transactions, :tx_index, :integer
  end
end
