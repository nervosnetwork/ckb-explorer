class AddBlockTimeToBlocks < ActiveRecord::Migration[6.0]
  def change
    add_column :blocks, :block_time, :decimal, precision: 13
    add_column :forked_blocks, :block_time, :decimal, precision: 13
  end
end
