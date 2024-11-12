class CreateCellDepsOutPoint < ActiveRecord::Migration[7.0]
  def change
    create_table :cell_deps_out_points do |t|
      t.binary :tx_hash
      t.integer :cell_index
      t.bigint :deployed_cell_output_id
      t.bigint :contract_cell_id

      t.timestamps
    end

    add_index :cell_deps_out_points, %i[contract_cell_id deployed_cell_output_id], name: "index_cell_deps_out_points_on_contract_cell_id_deployed_cell_id", unique: true
  end
end
