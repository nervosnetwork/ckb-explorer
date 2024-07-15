class RenameCellOutputsToCellOutputsOld < ActiveRecord::Migration[7.0]
  def up
    rename_table :cell_outputs, :cell_outputs_old
  end

  def down
    rename_table :cell_outputs_old, :cell_outputs
  end
end
