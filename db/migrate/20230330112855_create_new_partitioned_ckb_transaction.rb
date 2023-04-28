class CreateNewPartitionedCkbTransaction < ActiveRecord::Migration[7.0]
  def up
    execute <<~SQL
      CREATE TABLE partitioned_ckb_transactions (
          id bigserial NOT NULL,
          tx_hash bytea,
          block_id bigint,
          block_number bigint,
          block_timestamp bigint,
          tx_status integer DEFAULT 2 NOT NULL,
          version integer DEFAULT 0 NOT NULL,
          is_cellbase boolean DEFAULT false,
          transaction_fee bigint,
          created_at timestamp without time zone DEFAULT now() NOT NULL,
          updated_at timestamp without time zone DEFAULT now() NOT NULL,
          live_cell_changes integer,
          capacity_involved numeric(30,0),
          tags character varying[] DEFAULT '{}'::character varying[],
          bytes bigint DEFAULT 0,
          cycles bigint,
          confirmation_time integer,
          primary key (id, tx_status)
      ) PARTITION BY LIST (tx_status);
    SQL
    execute <<-SQL
      CREATE TABLE ckb_transactions_pending
      PARTITION OF partitioned_ckb_transactions
      FOR VALUES IN (0)
    SQL
    execute <<-SQL
      CREATE TABLE ckb_transactions_committed
      PARTITION OF partitioned_ckb_transactions
      FOR VALUES IN (2)
    SQL
    execute <<-SQL
      CREATE TABLE ckb_transactions_proposed
      PARTITION OF partitioned_ckb_transactions
      FOR VALUES IN (1)
    SQL
    execute <<-SQL
      CREATE TABLE ckb_transactions_rejected
      PARTITION OF partitioned_ckb_transactions
      FOR VALUES IN (3)
    SQL
    add_index :partitioned_ckb_transactions, :tx_hash, using: :hash
    add_index :partitioned_ckb_transactions, [:block_id, :block_timestamp], name: :idx_ckb_txs_for_blocks
    add_index :partitioned_ckb_transactions, [:block_timestamp, :id], order: { block_timestamp: "DESC NULLS LAST" }, name: :idx_ckb_txs_timestamp
    add_index :partitioned_ckb_transactions, :tags, using: :gin
    execute <<-SQL
      alter table partitioned_ckb_transactions
      add constraint ckb_tx_uni_tx_hash unique(tx_status, tx_hash)
    SQL
  end

  def down
    drop_table :partitioned_ckb_transactions
  end
end
