class AddLockedCapacityToDailyStatistic < ActiveRecord::Migration[6.0]
  def change
    add_column :daily_statistics, :locked_capacity, :decimal, precision: 30
  end
end
