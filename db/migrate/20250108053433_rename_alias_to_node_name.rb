class RenameAliasToNodeName < ActiveRecord::Migration[7.0]
  def change
    rename_column :fiber_graph_nodes, :alias, :node_name
  end
end
