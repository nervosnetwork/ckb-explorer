class CreateBitcoinVins < ActiveRecord::Migration[7.0]
  def change
    create_table :bitcoin_vins do |t|
      t.bigint :previous_bitcoin_vout_id
      t.bigint :ckb_transaction_id
      t.bigint :cell_input_id

      t.timestamps
    end

    add_index :bitcoin_vins, :ckb_transaction_id
    add_index :bitcoin_vins, %i[ckb_transaction_id cell_input_id], unique: true
  end
end
