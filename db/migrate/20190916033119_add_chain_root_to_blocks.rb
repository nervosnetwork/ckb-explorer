class AddChainRootToBlocks < ActiveRecord::Migration[6.0]
  def change
    add_column :blocks, :chain_root, :binary
    add_column :uncle_blocks, :chain_root, :binary
    add_column :forked_blocks, :chain_root, :binary
  end
end
