class ChangeDifficultyNonceAndSinceToDecimal < ActiveRecord::Migration[6.0]
  def change
    remove_column :blocks, :difficulty, :string
    remove_column :blocks, :nonce, :string
    remove_column :blocks, :start_number, :string
    remove_column :blocks, :length, :string
    add_column :blocks, :difficulty, :decimal, precision: 30, scale: 0, default: 0
    add_column :blocks, :nonce, :decimal, precision: 30, scale: 0, default: 0
    add_column :blocks, :start_number, :decimal, precision: 30, scale: 0, default: 0
    add_column :blocks, :length, :decimal, precision: 30, scale: 0, default: 0

    remove_column :uncle_blocks, :difficulty, :string
    remove_column :uncle_blocks, :nonce, :string
    add_column :uncle_blocks, :difficulty, :decimal, precision: 30, scale: 0, default: 0
    add_column :uncle_blocks, :nonce, :decimal, precision: 30, scale: 0, default: 0

    remove_column :forked_blocks, :difficulty, :string
    remove_column :forked_blocks, :nonce, :string
    remove_column :forked_blocks, :start_number, :string
    remove_column :forked_blocks, :length, :string
    add_column :forked_blocks, :difficulty, :decimal, precision: 30, scale: 0, default: 0
    add_column :forked_blocks, :nonce, :decimal, precision: 30, scale: 0, default: 0
    add_column :forked_blocks, :start_number, :decimal, precision: 30, scale: 0, default: 0
    add_column :forked_blocks, :length, :decimal, precision: 30, scale: 0, default: 0

    remove_column :cell_inputs, :since, :string
    add_column :cell_inputs, :since, :decimal, precision: 30, scale: 0, default: 0
  end
end
