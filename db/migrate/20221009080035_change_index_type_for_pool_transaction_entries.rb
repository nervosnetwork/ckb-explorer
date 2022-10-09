class ChangeIndexTypeForPoolTransactionEntries < ActiveRecord::Migration[6.1]
  def self.up
    remove_index :pool_transaction_entries, name: "index_pool_transaction_entries_on_tx_hash"
    add_index :pool_transaction_entries, :tx_hash, using: 'hash'
  end

  def self.down
    remove_index :pool_transaction_entries, name: "index_pool_transaction_entries_on_tx_hash"
    add_index :pool_transaction_entries, :tx_hash
  end
end
