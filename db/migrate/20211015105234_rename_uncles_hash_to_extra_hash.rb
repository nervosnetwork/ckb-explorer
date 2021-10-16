class RenameUnclesHashToExtraHash < ActiveRecord::Migration[6.1]
  def change
    rename_column :blocks, :uncles_hash, :extra_hash
    rename_column :forked_blocks, :uncles_hash, :extra_hash
    rename_column :uncle_blocks, :uncles_hash, :extra_hash
  end
end
