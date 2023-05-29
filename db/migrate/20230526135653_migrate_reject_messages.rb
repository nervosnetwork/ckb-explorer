class MigrateRejectMessages < ActiveRecord::Migration[7.0]
  def change
    execute <<~SQL
      INSERT INTO reject_reasons (ckb_transaction_id, message)
      SELECT ckb_transactions.id, pool_transaction_entries.detailed_message
      FROM ckb_transactions
      JOIN pool_transaction_entries
      ON ckb_transactions.tx_hash = pool_transaction_entries.tx_hash
      where pool_transaction_entries.tx_status = 3
    SQL
    execute <<~SQL
      UPDATE ckb_transactions
      SET tx_status = pool_transaction_entries.tx_status
      FROM pool_transaction_entries
      WHERE ckb_transactions.tx_hash = pool_transaction_entries.tx_hash
      AND pool_transaction_entries.tx_status = 3
    SQL
  end
end
