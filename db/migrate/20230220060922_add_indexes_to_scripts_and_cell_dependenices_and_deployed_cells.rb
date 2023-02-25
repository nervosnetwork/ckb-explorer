class AddIndexesToScriptsAndCellDependenicesAndDeployedCells < ActiveRecord::Migration[7.0]
  def change
    add_index :scripts, :contract_id
    add_index :cell_dependencies, :contract_id
    add_index :cell_dependencies, :script_id
    add_index :cell_dependencies, :contract_cell_id
    add_index :deployed_cells, :cell_output_id
    add_index :deployed_cells, :contract_id
  end
end
