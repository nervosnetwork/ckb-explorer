class AddHolderCountToDailyStatistic < ActiveRecord::Migration[7.0]
  def change
    add_column :daily_statistics, :holder_count, :integer
  end
end
