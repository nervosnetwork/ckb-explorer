class AddTotalSupplyToDailyStatistic < ActiveRecord::Migration[6.0]
  def change
    add_column :daily_statistics, :total_supply, :decimal, precision: 30
  end
end
