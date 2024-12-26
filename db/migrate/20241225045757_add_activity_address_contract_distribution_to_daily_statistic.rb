class AddActivityAddressContractDistributionToDailyStatistic < ActiveRecord::Migration[7.0]
  def change
    add_column :daily_statistics, :activity_address_contract_distribution, :jsonb
  end
end
