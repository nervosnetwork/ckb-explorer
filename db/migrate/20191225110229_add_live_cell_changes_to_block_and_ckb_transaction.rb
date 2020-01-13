class AddLiveCellChangesToBlockAndCkbTransaction < ActiveRecord::Migration[6.0]
  def change
    add_column :blocks, :live_cell_changes, :integer
    add_column :ckb_transactions, :live_cell_changes, :integer
  end
end
