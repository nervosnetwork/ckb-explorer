class AddIndexOnTxStatusToPoolTransactionEntries < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def change
    add_index :pool_transaction_entries, :tx_status, algorithm: :concurrently
  end
end
