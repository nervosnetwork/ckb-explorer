class AddDifficultyToBlock < ActiveRecord::Migration[7.0]
  def change
    add_column :blocks, :difficulty, :decimal, precision: 78, scale: 0
    add_column :forked_blocks, :difficulty, :decimal, precision: 78, scale: 0
    add_column :uncle_blocks, :difficulty, :decimal, precision: 78, scale: 0
  end
end
