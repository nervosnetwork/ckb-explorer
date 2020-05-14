class AddCirculationRatioToDailyStatistic < ActiveRecord::Migration[6.0]
  def change
    add_column :daily_statistics, :circulation_ratio, :decimal
  end
end
