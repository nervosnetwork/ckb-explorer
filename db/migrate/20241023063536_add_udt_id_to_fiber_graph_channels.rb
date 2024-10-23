class AddUdtIdToFiberGraphChannels < ActiveRecord::Migration[7.0]
  def change
    add_column :fiber_graph_channels, :udt_id, :bigint
  end
end
