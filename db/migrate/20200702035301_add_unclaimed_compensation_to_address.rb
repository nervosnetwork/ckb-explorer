class AddUnclaimedCompensationToAddress < ActiveRecord::Migration[6.0]
  def change
    add_column :addresses, :unclaimed_compensation, :decimal, precision: 30
  end
end
