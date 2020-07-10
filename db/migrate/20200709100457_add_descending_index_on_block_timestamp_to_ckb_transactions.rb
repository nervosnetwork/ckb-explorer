class AddDescendingIndexOnBlockTimestampToCkbTransactions < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def change
    add_index :ckb_transactions, :block_timestamp, order: { block_timestamp: "DESC NULLS LAST" }, algorithm: :concurrently
  end
end
