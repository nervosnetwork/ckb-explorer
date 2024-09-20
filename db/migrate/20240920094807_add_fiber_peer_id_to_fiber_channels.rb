class AddFiberPeerIdToFiberChannels < ActiveRecord::Migration[7.0]
  def change
    add_column :fiber_channels, :fiber_peer_id, :integer
    add_index :fiber_channels, :fiber_peer_id
  end
end
