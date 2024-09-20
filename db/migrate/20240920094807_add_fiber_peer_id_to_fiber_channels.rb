class AddFiberPeerIdToFiberChannels < ActiveRecord::Migration[7.0]
  def change
    rename_column :fiber_channels, :sent_tlc_balance, :offered_tlc_balance
    add_column :fiber_channels, :fiber_peer_id, :integer
    add_index :fiber_channels, :fiber_peer_id
  end
end
