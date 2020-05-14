class AddEpochLengthDistributionToEpochStatistics < ActiveRecord::Migration[6.0]
  def change
    add_column :epoch_statistics, :epoch_length_distribution, :json
  end
end
