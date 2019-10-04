class ReplaceDifficultyWithCompactTarget < ActiveRecord::Migration[6.0]
  def change
    remove_column :blocks, :witnesses_root, :binary
    remove_column :blocks, :difficulty, :decimal
    add_column :blocks, :compact_target, :decimal, precision: 20, scale: 0

    remove_column :uncle_blocks, :witnesses_root, :binary
    remove_column :uncle_blocks, :uncles_count, :integer
    remove_column :uncle_blocks, :difficulty, :decimal
    add_column :uncle_blocks, :compact_target, :decimal, precision: 20, scale: 0

    remove_column :forked_blocks, :witnesses_root, :binary
    remove_column :forked_blocks, :difficulty, :decimal
    add_column :forked_blocks, :compact_target, :decimal, precision: 20, scale: 0
  end
end
