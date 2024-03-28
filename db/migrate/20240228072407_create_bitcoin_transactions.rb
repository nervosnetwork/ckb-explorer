class CreateBitcoinTransactions < ActiveRecord::Migration[7.0]
  def change
    create_table :bitcoin_transactions do |t|
      t.binary :txid
      t.binary :hash
      t.bigint :time
      t.binary :block_hash
      t.bigint :block_height

      t.timestamps
    end

    add_index :bitcoin_transactions, :txid, unique: true
  end
end
