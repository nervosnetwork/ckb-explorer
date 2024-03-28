class RenameHashToTxHash < ActiveRecord::Migration[7.0]
  def change
    rename_column :bitcoin_transactions, :hash, :tx_hash
    rename_column :bitcoin_vouts, :hex, :data
  end
end
