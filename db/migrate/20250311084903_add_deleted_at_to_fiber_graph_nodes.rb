class AddDeletedAtToFiberGraphNodes < ActiveRecord::Migration[7.0]
  def change
    add_column :fiber_graph_nodes, :deleted_at, :datetime
    add_column :fiber_udt_cfg_infos, :deleted_at, :datetime
    add_column :fiber_graph_channels, :deleted_at, :datetime

    add_index :fiber_graph_nodes, :deleted_at
    add_index :fiber_graph_channels, :deleted_at
    add_index :fiber_udt_cfg_infos, :deleted_at
  end
end
