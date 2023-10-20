class RemoveReferringCellCellOutputIdIndex < ActiveRecord::Migration[7.0]
  def change
    remove_index :referring_cells, name: :index_referring_cells_on_cell_output_id, column: :cell_output_id
  end
end
