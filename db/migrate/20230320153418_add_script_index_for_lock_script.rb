class AddScriptIndexForLockScript < ActiveRecord::Migration[7.0]
  def change
    add_index :lock_scripts, :script_id
    add_index :type_scripts, :script_id
  end
end
