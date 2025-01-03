class UpdateFiberGraphChannels < ActiveRecord::Migration[7.0]
  def change
    remove_column :fiber_graph_channels, :funding_tx_block_number, :bigint
    remove_column :fiber_graph_channels, :funding_tx_index, :integer
    remove_column :fiber_graph_channels, :last_updated_timestamp, :bigint
    remove_column :fiber_graph_channels, :node1_to_node2_fee_rate, :decimal, precision: 30, default: 0.0
    remove_column :fiber_graph_channels, :node2_to_node1_fee_rate, :decimal, precision: 30, default: 0.0

    add_column :fiber_graph_channels, :last_updated_timestamp_of_node1, :bigint
    add_column :fiber_graph_channels, :last_updated_timestamp_of_node2, :bigint
    add_column :fiber_graph_channels, :fee_rate_of_node1, :decimal, precision: 30, default: 0.0
    add_column :fiber_graph_channels, :fee_rate_of_node2, :decimal, precision: 30, default: 0.0
  end
end
