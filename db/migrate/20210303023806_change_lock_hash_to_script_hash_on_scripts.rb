class ChangeLockHashToScriptHashOnScripts < ActiveRecord::Migration[6.0]
  def change
    rename_column :lock_scripts, :lock_hash, :script_hash
    rename_column :type_scripts, :lock_hash, :script_hash
  end
end
