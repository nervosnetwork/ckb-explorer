class AddDifficultyToBlock < ActiveRecord::Migration[7.0]
  def change
    add_column :blocks, :difficulty, :numeric, precision: 78, scale: 0
    add_column :forked_blocks, :difficulty, :numeric, precision: 78, scale: 0
    add_column :uncle_blocks, :difficulty, :numeric, precision: 78, scale: 0
  end
end
