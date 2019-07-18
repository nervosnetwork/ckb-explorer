class AddGeneratedByAndConsumedByIdToCellOutputs < ActiveRecord::Migration[5.2]
  def change
    add_column :cell_outputs, :generated_by_id, :decimal, precision: 30, scale: 0
    add_column :cell_outputs, :consumed_by_id, :decimal, precision: 30, scale: 0

    add_index :cell_outputs, :generated_by_id
    add_index :cell_outputs, :consumed_by_id
  end
end
