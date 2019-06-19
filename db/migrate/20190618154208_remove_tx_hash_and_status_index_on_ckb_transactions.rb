class RemoveTxHashAndStatusIndexOnCkbTransactions < ActiveRecord::Migration[5.2]
  def change
    remove_index :ckb_transactions, name: "index_ckb_transactions_on_tx_hash_and_status", column: [:tx_hash, :status]
  end
end
