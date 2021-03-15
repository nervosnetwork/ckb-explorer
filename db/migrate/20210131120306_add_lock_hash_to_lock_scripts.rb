class AddLockHashToLockScripts < ActiveRecord::Migration[6.0]
  def change
    add_column :lock_scripts, :lock_hash, :string
    add_column :type_scripts, :lock_hash, :string
  end
end
