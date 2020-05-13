class AddEpochTimeToEpochStatistics < ActiveRecord::Migration[6.0]
  def change
    add_column :epoch_statistics, :epoch_time, :decimal, precision: 13
  end
end
