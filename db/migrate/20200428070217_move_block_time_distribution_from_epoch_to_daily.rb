class MoveBlockTimeDistributionFromEpochToDaily < ActiveRecord::Migration[6.0]
  def change
    remove_column :epoch_statistics, :block_time_distribution
    add_column :daily_statistics, :block_time_distribution, :jsonb
  end
end
