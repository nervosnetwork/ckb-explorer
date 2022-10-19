class ChangeIndexTypeForPoolTransactionEntries < ActiveRecord::Migration[6.1]
  def self.up
    remove_index :pool_transaction_entries, name: "index_pool_transaction_entries_on_tx_hash"
    add_index :pool_transaction_entries, :tx_hash, using: 'hash'
    execute "alter table public.pool_transaction_entries add constraint unique_tx_hash unique (tx_hash);"
  end

  def self.down
    execute "alter table public.pool_transaction_entries drop constraint unique_tx_hash;"
    remove_index :pool_transaction_entries, name: "index_pool_transaction_entries_on_tx_hash"
    add_index :pool_transaction_entries, :tx_hash
  end
end
