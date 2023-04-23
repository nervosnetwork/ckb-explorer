class ChangeIndexTypeForTypeScripts < ActiveRecord::Migration[6.1]
  def self.up
    remove_index :type_scripts, name: "index_type_scripts_on_script_hash"
    add_index :type_scripts, :script_hash, using: 'hash'
  end

  def self.down
    remove_index :type_scripts, name: "index_type_scripts_on_script_hash"
    add_index :type_scripts, :script_hash
  end
end
