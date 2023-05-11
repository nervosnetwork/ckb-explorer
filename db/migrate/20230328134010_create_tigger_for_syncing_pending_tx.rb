class CreateTiggerForSyncingPendingTx < ActiveRecord::Migration[7.0]
  def self.up
    execute <<~SQL
      CREATE OR REPLACE FUNCTION insert_into_ckb_transactions()
      RETURNS TRIGGER AS $$
      DECLARE
          header_deps_size integer;
          i integer;
          header_hash bytea;
          transaction_id bigint;
          w text;
          out_point jsonb;
          cell_output_record record;
      BEGIN
        INSERT INTO ckb_transactions
        (
          tx_status, tx_hash,
          bytes, cycles, version,
          transaction_fee, created_at, updated_at
        )
        VALUES
        (NEW.tx_status, NEW.tx_hash,
        NEW.tx_size, NEW.cycles, COALESCE(NEW.version, 0),
        NEW.transaction_fee, NOW(), NOW()
        )
        RETURNING id into transaction_id;

        -- insert witnesses
        i := 0;
        for w in
          select jsonb_array_elements_text(NEW.witnesses)
        loop
          INSERT INTO witnesses (ckb_transaction_id, index, data)
          values
          (transaction_id, i, (E'\\x' || substring(w from 3))::bytea);
          i := i+1;
        end loop;

        -- insert header_deps
        i := 0;
        for w in
          select jsonb_array_elements_text(NEW.header_deps)
        loop
          INSERT INTO header_dependencies
          (ckb_transaction_id, header_hash, index)
          values
          (transaction_id, (E'\\x' || substring(w from 3))::bytea, i);
        end loop;

        -- insert cell_deps
        for out_point in
          select jsonb_array_elements(NEW.cell_deps)
        loop
          SELECT id, tx_hash, cell_index
          INTO cell_output_record
          FROM cell_outputs
          WHERE tx_hash = (E'\\x' || substring((out_point->'out_point'->>'tx_hash') from 3))::bytea
          AND cell_index = (out_point->'out_point'->>'index')::integer;

          IF FOUND THEN
            insert into cell_dependencies
            (ckb_transaction_id, contract_cell_id, dep_type, implicit)
            values(
              transaction_id, cell_output_record.id,
              CASE WHEN out_point->>'dep_type' = 'code' THEN 0
                   WHEN out_point->>'dep_type' = 'dep_group' THEN 1
                   ELSE NULL
              END, false
            );
          END IF;
        end loop;

        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    SQL

    execute <<~SQL
      CREATE TRIGGER insert_ckb_transactions
      AFTER INSERT ON pool_transaction_entries
      FOR EACH ROW
      EXECUTE FUNCTION insert_into_ckb_transactions();
    SQL
  end

  def self.down
    execute <<-SQL
    DROP TRIGGER insert_ckb_transactions ON pool_transaction_entries
    SQL

    execute "DROP FUNCTION insert_into_ckb_transactions()"
  end
end
