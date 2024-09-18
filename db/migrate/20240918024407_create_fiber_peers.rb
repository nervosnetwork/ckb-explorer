class CreateFiberPeers < ActiveRecord::Migration[7.0]
  def change
    create_table :fiber_peers do |t|
      t.string :name
      t.string :peer_id
      t.string :rpc_listening_addr
      t.datetime :first_channel_opened_at
      t.datetime :last_channel_updated_at

      t.timestamps
    end
  end
end
