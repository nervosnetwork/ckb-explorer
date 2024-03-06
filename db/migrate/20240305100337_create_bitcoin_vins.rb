class CreateBitcoinVins < ActiveRecord::Migration[7.0]
  def change
    create_table :bitcoin_vins do |t|
      t.bigint :previous_bitcoin_vout_id
      t.bigint :bitcoin_transaction_id
      t.bigint :ckb_transaction_id

      t.timestamps
    end

    add_index :bitcoin_vins, :ckb_transaction_id
    add_index :bitcoin_vins, %i[bitcoin_transaction_id previous_bitcoin_vout_id], unique: true, name: "prev_bitcoin_vout"
  end
end
