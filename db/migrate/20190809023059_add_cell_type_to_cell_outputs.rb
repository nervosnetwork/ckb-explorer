class AddCellTypeToCellOutputs < ActiveRecord::Migration[5.2]
  def change
    add_column :cell_outputs, :cell_type, :integer, default: 0
  end
end
