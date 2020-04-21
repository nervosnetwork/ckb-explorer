class AddBlockSizeToBlock < ActiveRecord::Migration[6.0]
  def change
    add_column :blocks, :block_size, :integer
    add_column :forked_blocks, :block_size, :integer
  end
end
