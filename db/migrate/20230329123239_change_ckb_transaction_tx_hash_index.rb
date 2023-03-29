class ChangeCkbTransactionTxHashIndex < ActiveRecord::Migration[7.0]
  def up
    remove_index :ckb_transactions, name: :index_ckb_transactions_on_tx_hash_and_block_id
    add_index :ckb_transactions, :tx_hash, using: :hash
    execute <<-SQL
    alter table ckb_transactions add constraint ckb_tx_unique_tx_hash unique(tx_hash)
    SQL
  end

  def down
    remove_index :ckb_transactions, :tx_hash
    add_index :ckb_transactions, [:tx_hash, :block_id], unique: true
  end
end
