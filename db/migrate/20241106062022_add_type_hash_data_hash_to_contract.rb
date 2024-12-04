class AddTypeHashDataHashToContract < ActiveRecord::Migration[7.0]
  def change
    add_column :contracts, :type_hash, :binary
    add_column :contracts, :data_hash, :binary
    add_column :contracts, :deployed_cell_output_id, :bigint
    add_column :contracts, :is_type_script, :boolean
    add_column :contracts, :is_lock_script, :boolean
  end
end
