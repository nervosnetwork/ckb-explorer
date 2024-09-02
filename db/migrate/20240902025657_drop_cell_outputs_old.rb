class DropCellOutputsOld < ActiveRecord::Migration[7.0]
  def change
    drop_table :cell_outputs_old, if_exists: true
  end
end
