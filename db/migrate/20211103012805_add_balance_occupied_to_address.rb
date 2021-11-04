class AddBalanceOccupiedToAddress < ActiveRecord::Migration[6.1]
  def change
    add_column :addresses, :balance_occupied, :decimal, precision: 30, default: 0
  end
end
