class AddClaimedAndUnclaimedCompensationToDaoContract < ActiveRecord::Migration[6.0]
  def change
    rename_column :dao_contracts, :interest_granted, :claimed_compensation
    add_column :dao_contracts, :unclaimed_compensation, :decimal, precision: 30, scale: 0
  end
end
