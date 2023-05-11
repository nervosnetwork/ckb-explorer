class ChangeIndexTypeForLockScripts < ActiveRecord::Migration[6.1]
  def self.up
    remove_index :lock_scripts, name: "index_lock_scripts_on_script_hash"
    add_index :lock_scripts, :script_hash, using: 'hash'
  end

  def self.down
    remove_index :lock_scripts, name: "index_lock_scripts_on_script_hash"
    add_index :lock_scripts, :script_hash
  end
end
