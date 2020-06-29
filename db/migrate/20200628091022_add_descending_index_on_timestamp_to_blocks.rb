class AddDescendingIndexOnTimestampToBlocks < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!
  def change
    remove_index :blocks, name: "index_blocks_on_timestamp", column: :timestamp, algorithm: :concurrently if index_exists?(:blocks, :timestamp)
    add_index :blocks, :timestamp, order: { timestamp: "DESC NULLS LAST" }, algorithm: :concurrently
  end
end
