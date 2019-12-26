class AddHashRateToEpochStatistic < ActiveRecord::Migration[6.0]
  def change
    add_column :epoch_statistics, :hash_rate, :string
  end
end
