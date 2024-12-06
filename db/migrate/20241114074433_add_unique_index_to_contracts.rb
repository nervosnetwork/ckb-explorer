class AddUniqueIndexToContracts < ActiveRecord::Migration[7.0]
  def change
    add_index :contracts, :deployed_cell_output_id, unique: true
  end
end
