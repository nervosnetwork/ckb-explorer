class CreateFiberTransactions < ActiveRecord::Migration[7.0]
  def change
    create_table :fiber_transactions do |t|
      t.integer :fiber_peer_id
      t.integer :fiber_channel_id
      t.integer :ckb_transaction_id

      t.timestamps
    end
  end
end
