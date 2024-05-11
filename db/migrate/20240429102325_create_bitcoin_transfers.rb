class CreateBitcoinTransfers < ActiveRecord::Migration[7.0]
  def change
    create_table :bitcoin_transfers do |t|
      t.bigint :bitcoin_transaction_id
      t.bigint :ckb_transaction_id
      t.bigint :cell_output_id
      t.integer :lock_type, default: 0

      t.timestamps
    end

    add_index :bitcoin_transfers, :ckb_transaction_id
    add_index :bitcoin_transfers, :bitcoin_transaction_id
    add_index :bitcoin_transfers, :cell_output_id, unique: true
  end
end
