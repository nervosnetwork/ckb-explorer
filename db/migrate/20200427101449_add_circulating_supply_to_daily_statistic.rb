class AddCirculatingSupplyToDailyStatistic < ActiveRecord::Migration[6.0]
  def change
    add_column :daily_statistics, :circulating_supply, :decimal
  end
end
