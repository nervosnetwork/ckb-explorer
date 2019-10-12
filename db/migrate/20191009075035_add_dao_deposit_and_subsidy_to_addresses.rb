class AddDaoDepositAndSubsidyToAddresses < ActiveRecord::Migration[6.0]
  def change
    add_column :addresses, :dao_deposit, :decimal, precision: 30, scale: 0, default: 0
    add_column :addresses, :subsidy, :decimal, precision: 30, scale: 0, default: 0
  end
end
