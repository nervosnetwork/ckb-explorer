class AddUpdateInfoFieldsToFiberGraphChannels < ActiveRecord::Migration[7.0]
  def change
    add_column :fiber_graph_channels, :update_info_of_node1, :jsonb, default: {}
    add_column :fiber_graph_channels, :update_info_of_node2, :jsonb, default: {}
  end
end
