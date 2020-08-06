class AdjustBlockTimestampIndex < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!
  def change
    remove_index :ckb_transactions, name: :index_ckb_transactions_on_block_timestamp, column: :block_timestamp, algorithm: :concurrently if index_exists?(:ckb_transactions, :block_timestamp)
    add_index :ckb_transactions, [:block_timestamp, :id], order: { block_timestamp: "DESC NULLS LAST", id: "desc" }, algorithm: :concurrently
  end
end
