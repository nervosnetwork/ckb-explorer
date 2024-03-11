class CreateBitcoinVouts < ActiveRecord::Migration[7.0]
  def change
    create_table :bitcoin_vouts do |t|
      t.bigint :bitcoin_transaction_id
      t.bigint :bitcoin_address_id
      t.binary :hex
      t.integer :index
      t.text :asm
      t.boolean :op_return, default: false
      t.bigint :ckb_transaction_id
      t.bigint :cell_output_id
      t.bigint :address_id

      t.timestamps
    end

    add_index :bitcoin_vouts, %i[bitcoin_transaction_id index], unique: true
    add_index :bitcoin_vouts, :bitcoin_address_id
    add_index :bitcoin_vouts, :ckb_transaction_id
  end
end
