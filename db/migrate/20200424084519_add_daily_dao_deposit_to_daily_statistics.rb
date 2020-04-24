class AddDailyDaoDepositToDailyStatistics < ActiveRecord::Migration[6.0]
  def change
    add_column :daily_statistics, :daily_dao_deposit, :decimal, precision: 30
    add_column :daily_statistics, :daily_dao_depositors_count, :integer
    add_column :daily_statistics, :daily_dao_withdraw, :decimal, precision: 30
  end
end
