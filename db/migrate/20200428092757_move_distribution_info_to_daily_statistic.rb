class MoveDistributionInfoToDailyStatistic < ActiveRecord::Migration[6.0]
  def change
    remove_column :epoch_statistics, :epoch_time_distribution
    remove_column :epoch_statistics, :epoch_length_distribution
    add_column :daily_statistics, :epoch_time_distribution, :jsonb
    add_column :daily_statistics, :epoch_length_distribution, :jsonb
  end
end
