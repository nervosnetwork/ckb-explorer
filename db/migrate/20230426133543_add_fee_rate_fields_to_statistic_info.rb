class AddFeeRateFieldsToStatisticInfo < ActiveRecord::Migration[7.0]
  def change
    add_column :statistic_infos, :pending_transaction_fee_rates, :jsonb
    add_column :statistic_infos, :transaction_fee_rates, :jsonb
    # Ex:- add_column("admin_users", "username", :string, :limit =>25, :after => "email")
  end
end
