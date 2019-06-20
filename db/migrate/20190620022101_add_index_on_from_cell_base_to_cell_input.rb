class AddIndexOnFromCellBaseToCellInput < ActiveRecord::Migration[5.2]
  def change
    remove_index :cell_inputs, column: :ckb_transaction_id
    add_index :cell_inputs, [:ckb_transaction_id, :from_cell_base]
  end
end
