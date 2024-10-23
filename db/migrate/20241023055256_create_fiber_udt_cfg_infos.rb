class CreateFiberUdtCfgInfos < ActiveRecord::Migration[7.0]
  def change
    create_table :fiber_udt_cfg_infos do |t|
      t.bigint :fiber_graph_node_id
      t.bigint :udt_id
      t.decimal :auto_accept_amount, precision: 64, scale: 2, default: 0.0

      t.timestamps
    end

    add_index :fiber_udt_cfg_infos, %i[fiber_graph_node_id udt_id], unique: true
  end
end
