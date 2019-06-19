class AddIndexOnBlockTimestampToCkbTransactions < ActiveRecord::Migration[5.2]
  def change
    remove_index :ckb_transactions, name: "index_ckb_transactions_on_block_id", column: :block_id
    add_index :ckb_transactions, [:block_id, :block_timestamp]
  end
end
