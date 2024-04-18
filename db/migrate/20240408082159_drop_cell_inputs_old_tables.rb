class DropCellInputsOldTables < ActiveRecord::Migration[7.0]
  def change
    drop_table :cell_inputs_old, if_exists: true
  end
end
