class AddUniqueConstraintForCellOutput < ActiveRecord::Migration[7.0]
  def change
    remove_index :cell_outputs, [:tx_hash, :cell_index]
    add_index :cell_outputs, [:tx_hash, :cell_index], unique: true
    add_index :cell_outputs, [:ckb_transaction_id, :cell_index], unique: true
    remove_index :cell_outputs, :ckb_transaction_id
  end
end
