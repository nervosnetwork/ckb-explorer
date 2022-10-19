class ChangeIndexTypeForBlocks < ActiveRecord::Migration[6.1]
  def self.up
    remove_index :blocks, name: "index_blocks_on_block_hash"
    add_index :blocks, :block_hash, using: 'hash'
  end

  def self.down
    remove_index :blocks, name: "index_blocks_on_block_hash"
    add_index :blocks, :block_hash
  end
end
