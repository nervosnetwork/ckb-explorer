class RemoveIndexesFromBlocks < ActiveRecord::Migration[5.2]
  def change
    remove_index :blocks, name: "index_blocks_on_block_hash_and_status", column: [:block_hash, :status]
    remove_index :blocks, name: "index_blocks_on_number_and_status", column: [:number, :status]
    remove_index :blocks, name: "index_blocks_on_status", column: :status
  end
end
