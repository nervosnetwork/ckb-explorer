class RemoveGeneratedByIdOfCellOutput < ActiveRecord::Migration[7.0]
  def change
    remove_column :cell_outputs, :generated_by_id, :decimal, precision: 30, scale: 0
  end
end
