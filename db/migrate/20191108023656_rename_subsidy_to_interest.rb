class RenameSubsidyToInterest < ActiveRecord::Migration[6.0]
  def change
    rename_column :addresses, :subsidy, :interest
    rename_column :dao_contracts, :subsidy_granted, :interest_granted
  end
end
