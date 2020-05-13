class AddAverageBlockTimeToDailyStatistics < ActiveRecord::Migration[6.0]
  def change
    add_column :daily_statistics, :average_block_time, :jsonb
  end
end
