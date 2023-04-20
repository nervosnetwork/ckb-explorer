class RefreshCellDependencyImplicit < ActiveRecord::Migration[7.0]
  def up
    execute <<~SQL
      CREATE OR REPLACE FUNCTION update_cell_dependencies_implicit()
      RETURNS VOID AS $$
      DECLARE
          cur CURSOR FOR SELECT id, cell_deps FROM ckb_transactions;
          transaction_id bigint;
          cell_deps jsonb;
          out_point jsonb;
          cell_output_record record;
      BEGIN
          OPEN cur;
          LOOP
              FETCH cur INTO transaction_id, cell_deps;
              EXIT WHEN NOT FOUND;

              FOR out_point IN
                  SELECT jsonb_array_elements(cell_deps)
              LOOP
                  SELECT id, tx_hash, cell_index
                  INTO cell_output_record
                  FROM cell_outputs
                  WHERE tx_hash = (E'\\x' || substring((out_point->'out_point'->>'tx_hash') from 3))::bytea
                  AND cell_index = (out_point->'out_point'->>'index')::integer;

                  IF FOUND THEN
                      UPDATE cell_dependencies
                      SET implicit = false
                      WHERE ckb_transaction_id = transaction_id
                      AND contract_cell_id = cell_output_record.id;
                  END IF;
              END LOOP;
          END LOOP;
          CLOSE cur;
      END;
      $$ LANGUAGE plpgsql;
    SQL
  end

  def down
    execute "DROP FUNCTION update_cell_dependencies_implicit();"
  end
end
