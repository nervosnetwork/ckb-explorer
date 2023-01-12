class AddCyclesToTransaction < ActiveRecord::Migration[7.0]
  def change
    add_column :ckb_transactions, :cycles, :integer
  end
end
