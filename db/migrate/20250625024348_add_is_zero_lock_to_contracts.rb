class AddIsZeroLockToContracts < ActiveRecord::Migration[7.0]
  def change
    add_column :contracts, :is_zero_lock, :boolean
  end
end
