class AddIndexesToReferringCells < ActiveRecord::Migration[7.0]
  def change
    add_index :referring_cells, [:contract_id, :cell_output_id], unique: true
    add_index :referring_cells, :cell_output_id, unique: true
  end
end
