class ChangeUniqueIndexScopeOnBlockHash < ActiveRecord::Migration[5.2]
  def change
    remove_index :blocks, name: :index_blocks_on_block_hash, column: :block_hash
    add_index :blocks, [:block_hash, :status], unique: true
  end
end
