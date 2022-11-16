class AddMedianTimestampToForkedBlocks < ActiveRecord::Migration[6.1]
  def change
    add_column :forked_blocks, :median_timestamp, :decimal, default: 0
  end
end
