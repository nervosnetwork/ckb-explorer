class ImportCellOutputsOldToCellOutputs < ActiveRecord::Migration[7.0]
  def up
    execute <<~SQL
      SET statement_timeout = 0;

      INSERT INTO cell_outputs (id, capacity, ckb_transaction_id, status, address_id, block_id, tx_hash, cell_index, consumed_by_id, cell_type, data_size, occupied_capacity, block_timestamp, consumed_block_timestamp, type_hash, udt_amount, dao, lock_script_id, type_script_id, data_hash, created_at, updated_at)
      SELECT id, capacity, ckb_transaction_id, status, address_id, block_id, tx_hash, cell_index, consumed_by_id, cell_type, data_size, occupied_capacity, block_timestamp, consumed_block_timestamp, type_hash, udt_amount, dao, lock_script_id, type_script_id, data_hash, created_at, updated_at FROM cell_outputs_old;

      SELECT setval('cell_outputs_id_seq', (SELECT max(id) FROM cell_outputs));
    SQL
  end

  def down
    execute <<~SQL
      TRUNCATE TABLE cell_outputs;
    SQL
  end
end
