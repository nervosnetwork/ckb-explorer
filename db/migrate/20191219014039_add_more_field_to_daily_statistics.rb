class AddMoreFieldToDailyStatistics < ActiveRecord::Migration[6.0]
  def change
    add_column :daily_statistics, :dao_depositors_count, :string, default: "0"
    add_column :daily_statistics, :unclaimed_compensation, :string, default: "0"
    add_column :daily_statistics, :claimed_compensation, :string, default: "0"
    add_column :daily_statistics, :average_deposit_time, :string, default: "0"
    add_column :daily_statistics, :estimated_apc, :string, default: "0"
    add_column :daily_statistics, :mining_reward, :string, default: "0"
    add_column :daily_statistics, :deposit_compensation, :string, default: "0"
    add_column :daily_statistics, :treasury_amount, :string, default: "0"
  end
end
