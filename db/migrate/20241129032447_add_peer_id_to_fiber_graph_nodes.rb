class AddPeerIdToFiberGraphNodes < ActiveRecord::Migration[7.0]
  def change
    add_column :fiber_graph_nodes, :peer_id, :string
  end
end
