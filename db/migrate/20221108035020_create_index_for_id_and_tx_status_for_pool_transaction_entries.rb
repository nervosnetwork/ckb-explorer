class CreateIndexForIdAndTxStatusForPoolTransactionEntries < ActiveRecord::Migration[6.1]
  def self.up
    add_index :pool_transaction_entries, [:id, :tx_status]
  end

  def self.down
    remove_index :pool_transaction_entries, name: "index_pool_transaction_entries_on_id_and_tx_status"
  end
end
