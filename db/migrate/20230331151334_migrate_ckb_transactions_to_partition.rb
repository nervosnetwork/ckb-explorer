class MigrateCkbTransactionsToPartition < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    # insert ckb_transactions to partition
    execute <<~SQL
      insert into partitioned_ckb_transactions(
          id, tx_hash, tx_status, block_id, block_number,
          block_timestamp, version, is_cellbase, transaction_fee,
          created_at, updated_at,
          live_cell_changes, capacity_involved, tags,
          bytes, cycles, confirmation_time)
      SELECT id, tx_hash, 2, block_id, block_number,
          block_timestamp, version, is_cellbase, transaction_fee,
          created_at, updated_at,
          live_cell_changes, capacity_involved, tags,
          bytes, cycles, confirmation_time
      FROM ckb_transactions;
    SQL
  end
end
