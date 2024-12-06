class CreateFiberChannels < ActiveRecord::Migration[7.0]
  def change
    create_table :fiber_channels do |t|
      t.string :peer_id
      t.string :channel_id
      t.string :state_name
      t.string :state_flags, default: [], array: true
      t.decimal :local_balance, precision: 64, scale: 2, default: 0.0
      t.decimal :sent_tlc_balance, precision: 64, scale: 2, default: 0.0
      t.decimal :remote_balance, precision: 64, scale: 2, default: 0.0
      t.decimal :received_tlc_balance, precision: 64, scale: 2, default: 0.0
      t.datetime :shutdown_at

      t.timestamps
    end

    add_index :fiber_channels, %i[peer_id channel_id], unique: true
  end
end
