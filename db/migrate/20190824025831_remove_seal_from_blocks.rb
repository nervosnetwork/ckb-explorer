class RemoveSealFromBlocks < ActiveRecord::Migration[5.2]
  def change
    remove_column :blocks, :seal
    remove_column :forked_blocks, :seal
    remove_column :uncle_blocks, :seal

    add_column :blocks, :nonce, :string
    add_column :forked_blocks, :nonce, :string
    add_column :uncle_blocks, :nonce, :string
  end
end
