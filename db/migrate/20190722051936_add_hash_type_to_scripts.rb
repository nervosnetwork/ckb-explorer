class AddHashTypeToScripts < ActiveRecord::Migration[5.2]
  def change
    add_column :lock_scripts, :hash_type, :string
    add_column :type_scripts, :hash_type, :string
  end
end
