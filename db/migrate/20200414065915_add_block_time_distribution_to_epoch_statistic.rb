class AddBlockTimeDistributionToEpochStatistic < ActiveRecord::Migration[6.0]
  def change
    add_column :epoch_statistics, :block_time_distribution, :jsonb
  end
end
