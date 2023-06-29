class AddMissingIndexForCellInput < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!
  def change
    execute <<~SQL
            CREATE TABLE IF NOT EXISTS public.cell_inputs_new
            (
                id bigint NOT NULL DEFAULT nextval('cell_inputs_id_seq'::regclass),
                ckb_transaction_id bigint,
                created_at timestamp without time zone NOT NULL,
                updated_at timestamp without time zone NOT NULL,
                previous_cell_output_id bigint,
                from_cell_base boolean DEFAULT false,
                block_id bigint,
                since numeric(30,0) DEFAULT 0.0,
                cell_type integer DEFAULT 0,
                index integer,
                previous_tx_hash bytea,
                previous_index integer,
                CONSTRAINT cell_inputs_pkey_new PRIMARY KEY (id)
            );

      CREATE INDEX IF NOT EXISTS idx_cell_inputs_on_block_id
          ON public.cell_inputs_new USING btree
          (block_id ASC NULLS LAST)
          TABLESPACE pg_default;
      -- Index: index_cell_inputs_on_ckb_transaction_id

      -- DROP INDEX IF EXISTS public.index_cell_inputs_on_ckb_transaction_id;

      CREATE INDEX IF NOT EXISTS idx_cell_inputs_on_ckb_transaction_id
          ON public.cell_inputs_new USING btree
          (ckb_transaction_id ASC NULLS LAST)
          TABLESPACE pg_default;
      -- Index: index_cell_inputs_on_previous_cell_output_id

      -- DROP INDEX IF EXISTS public.index_cell_inputs_on_previous_cell_output_id;

      CREATE INDEX IF NOT EXISTS idx_cell_inputs_on_previous_cell_output_id
          ON public.cell_inputs_new USING btree
          (previous_cell_output_id ASC NULLS LAST)
          TABLESPACE pg_default;
      -- Index: index_cell_inputs_on_previous_tx_hash_and_previous_index

      -- DROP INDEX IF EXISTS public.index_cell_inputs_on_previous_tx_hash_and_previous_index;

      CREATE INDEX IF NOT EXISTS idx_cell_inputs_on_previous_tx_hash_and_previous_index
          ON public.cell_inputs_new USING btree
          (previous_tx_hash ASC NULLS LAST, previous_index ASC NULLS LAST)
          TABLESPACE pg_default;
    SQL

    execute <<-SQL
  insert into cell_inputs_new
      SELECT id,ckb_transaction_id,created_at,updated_at,previous_cell_output_id,from_cell_base,block_id,
      since,cell_type,ROW_NUMBER() OVER (PARTITION BY ckb_transaction_id ORDER BY id) - 1 AS index,previous_tx_hash,previous_index
      FROM cell_inputs;
    SQL
    execute <<-SQL
    ALTER TABLE cell_inputs rename to cell_inputs_old;
    SQL
    execute <<-SQL
    alter table cell_inputs_new rename to cell_inputs;
    SQL
  end
end
