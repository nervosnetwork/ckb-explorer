class AddIndexOnScripts < ActiveRecord::Migration[6.0]
  def change
    add_index :lock_scripts, :script_hash
    add_index :type_scripts, :script_hash
  end
end
