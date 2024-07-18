class CreateCellOutputs < ActiveRecord::Migration[7.0]
  def up
    execute <<-SQL
      CREATE TABLE cell_outputs (
        id bigserial NOT NULL,
        capacity numeric(64,2),
        ckb_transaction_id bigint,
        created_at timestamp without time zone NOT NULL,
        updated_at timestamp without time zone NOT NULL,
        status smallint DEFAULT 0,
        address_id numeric(30,0),
        block_id numeric(30,0),
        tx_hash bytea,
        cell_index integer,
        consumed_by_id numeric(30,0),
        cell_type integer DEFAULT 0,
        data_size integer,
        occupied_capacity numeric(30,0),
        block_timestamp numeric(30,0),
        consumed_block_timestamp numeric(30,0),
        type_hash character varying,
        udt_amount numeric(40,0),
        dao character varying,
        lock_script_id bigint,
        type_script_id bigint,
        data_hash bytea,
        primary key (id, status)
      )  PARTITION BY LIST (status);

      CREATE TABLE cell_outputs_live PARTITION OF cell_outputs
      FOR VALUES IN (0);

      CREATE TABLE cell_outputs_dead PARTITION OF cell_outputs
      FOR VALUES IN (1);

      CREATE TABLE cell_outputs_pending PARTITION OF cell_outputs
      FOR VALUES IN (2);

      CREATE TABLE cell_outputs_rejected PARTITION OF cell_outputs
      FOR VALUES IN (3);
    SQL
  end

  def down
    drop_table :cell_outputs
  end
end
