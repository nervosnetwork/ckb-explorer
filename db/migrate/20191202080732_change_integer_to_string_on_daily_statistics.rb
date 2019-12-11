class ChangeIntegerToStringOnDailyStatistics < ActiveRecord::Migration[6.0]
  def change
    change_column :daily_statistics, :transactions_count, :string
    change_column :daily_statistics, :addresses_count, :string
    change_column :daily_statistics, :total_dao_deposit, :string
  end
end
