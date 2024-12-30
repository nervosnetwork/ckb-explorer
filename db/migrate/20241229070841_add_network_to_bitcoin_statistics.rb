class AddNetworkToBitcoinStatistics < ActiveRecord::Migration[7.0]
  def change
    add_column :bitcoin_statistics, :network, :integer, default: :btc
    remove_index :bitcoin_statistics, :timestamp
    add_index :bitcoin_statistics, %i[timestamp network], unique: true
  end
end
