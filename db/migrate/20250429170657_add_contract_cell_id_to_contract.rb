class AddContractCellIdToContract < ActiveRecord::Migration[7.0]
  def change
    add_column :contracts, :contract_cell_id, :bigint
    remove_column :contracts, :deployed_cells_count
    remove_column :contracts, :total_deployed_cells_capacity
  end
end
