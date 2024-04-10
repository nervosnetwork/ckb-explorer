class CreateBitcoinStatistics < ActiveRecord::Migration[7.0]
  def change
    create_table :bitcoin_statistics do |t|
      t.bigint :timestamp
      t.integer :transactions_count, default: 0
      t.integer :addresses_count, default: 0
    end
  end
end
