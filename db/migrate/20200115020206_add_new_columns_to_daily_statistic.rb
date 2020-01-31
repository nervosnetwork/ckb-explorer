class AddNewColumnsToDailyStatistic < ActiveRecord::Migration[6.0]
  def change
    add_column :daily_statistics, :live_cells_count, :string, default: "0"
    add_column :daily_statistics, :dead_cells_count, :string, default: "0"
    add_column :daily_statistics, :avg_hash_rate, :string, default: "0"
    add_column :daily_statistics, :avg_difficulty, :string, default: "0"
    add_column :daily_statistics, :uncle_rate, :string, default: "0"
    add_column :daily_statistics, :total_depositors_count, :string, default: "0"
  end
end
