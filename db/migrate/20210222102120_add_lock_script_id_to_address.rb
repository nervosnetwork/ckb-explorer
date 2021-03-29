class AddLockScriptIdToAddress < ActiveRecord::Migration[6.0]
  def change
    add_column :addresses, :lock_script_id, :bigint
  end
end
