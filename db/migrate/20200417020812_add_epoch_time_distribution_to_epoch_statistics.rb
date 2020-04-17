class AddEpochTimeDistributionToEpochStatistics < ActiveRecord::Migration[6.0]
  def change
    add_column :epoch_statistics, :epoch_time_distribution, :jsonb
  end
end
