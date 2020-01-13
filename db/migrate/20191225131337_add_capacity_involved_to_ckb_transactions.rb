class AddCapacityInvolvedToCkbTransactions < ActiveRecord::Migration[6.0]
  def change
    add_column :ckb_transactions, :capacity_involved, :decimal, precision: 30, scale: 0
  end
end
