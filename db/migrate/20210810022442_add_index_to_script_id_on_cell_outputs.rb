class AddIndexToScriptIdOnCellOutputs < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!
  def change
    add_index :cell_outputs, :lock_script_id, algorithm: :concurrently
    add_index :cell_outputs, :type_script_id, algorithm: :concurrently
  end
end
