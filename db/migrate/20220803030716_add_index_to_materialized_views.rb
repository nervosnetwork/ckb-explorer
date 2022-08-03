class AddIndexToMaterializedViews < ActiveRecord::Migration[6.1]
  def change
    add_index :average_block_time_by_hour, :hour, unique: true
    add_index :rolling_avg_block_time, :timestamp, unique: true
  end
end
