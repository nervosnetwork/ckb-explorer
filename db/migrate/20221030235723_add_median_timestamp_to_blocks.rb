class AddMedianTimestampToBlocks < ActiveRecord::Migration[6.1]
  def change
    add_column :blocks, :median_timestamp, :decimal, default: 0
  end
end
