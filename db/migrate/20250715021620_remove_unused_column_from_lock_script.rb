class RemoveUnusedColumnFromLockScript < ActiveRecord::Migration[7.0]
  def change
    remove_column :lock_scripts, :cell_output_id, :bigint
    remove_column :lock_scripts, :script_id, :bigint
    remove_column :lock_scripts, :address_id, :bigint
  end
end
