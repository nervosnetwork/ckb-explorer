class AddAddressBalanceDistributionToDailyStatistics < ActiveRecord::Migration[6.0]
  def change
    add_column :daily_statistics, :address_balance_distribution, :jsonb
  end
end
