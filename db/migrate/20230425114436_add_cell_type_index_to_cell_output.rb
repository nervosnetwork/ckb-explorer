class AddCellTypeIndexToCellOutput < ActiveRecord::Migration[7.0]
  def change
    add_index :cell_outputs, :cell_type
  end
end
