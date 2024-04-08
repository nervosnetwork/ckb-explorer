class AddIndexOnBitcoinStatistics < ActiveRecord::Migration[7.0]
  def change
    add_index :bitcoin_statistics, :timestamp, unique: true
  end
end
