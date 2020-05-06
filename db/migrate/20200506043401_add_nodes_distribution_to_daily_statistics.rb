class AddNodesDistributionToDailyStatistics < ActiveRecord::Migration[6.0]
  def change
    add_column :daily_statistics, :nodes_distribution, :jsonb
    add_column :daily_statistics, :nodes_count, :integer
  end
end
