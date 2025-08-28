class AddBlockNumberIndexToCkbTransactions < ActiveRecord::Migration[7.0]
  def change
    add_index :ckb_transactions, :block_number
  end
end
