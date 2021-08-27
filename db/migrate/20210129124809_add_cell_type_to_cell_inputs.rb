class AddCellTypeToCellInputs < ActiveRecord::Migration[6.0]
  def change
    add_column :cell_inputs, :cell_type, :integer, default: 0
  end
end
