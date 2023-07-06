class AddUniqueIndexForCellInput < ActiveRecord::Migration[7.0]
  def change
    add_index :cell_inputs, [:ckb_transaction_id, :index], unique: true
    remove_index :cell_inputs, :ckb_transaction_id
  end
end
