class AddLockScriptIdAndTypeScriptIdToCellOutputs < ActiveRecord::Migration[6.0]
  def change
    add_column :cell_outputs, :lock_script_id, :bigint
    add_column :cell_outputs, :type_script_id, :bigint
  end
end
