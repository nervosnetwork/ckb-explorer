class AddScriptIdToTypeScriptsAndLockScripts < ActiveRecord::Migration[7.0]
  def change
    add_column :type_scripts, :script_id, :bigint
    add_column :lock_scripts, :script_id, :bigint
  end
end
