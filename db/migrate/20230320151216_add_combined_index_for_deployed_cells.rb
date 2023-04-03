class AddCombinedIndexForDeployedCells < ActiveRecord::Migration[7.0]
  def change
    change_column_null :deployed_cells, :cell_output_id, false
    change_column_null :deployed_cells, :contract_id, false
    remove_index :deployed_cells, :contract_id rescue nil
    remove_index :deployed_cells, :cell_output_id rescue nil
    DeployedCell.delete_all
    add_index :deployed_cells, [:contract_id, :cell_output_id], unique: true
    add_index :deployed_cells, :cell_output_id, unique: true
  end
end
