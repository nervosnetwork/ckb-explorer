class CleanCellInput < ActiveRecord::Migration[7.0]
  def up
    execute <<~SQL
      CREATE OR REPLACE PROCEDURE update_cell_inputs() LANGUAGE plpgsql AS $$
      DECLARE
        input_id BIGINT;
        input_output_id BIGINT;
        input_previous_output JSONB;
        input_tx_hash BYTEA;
        input_cell_index BIGINT;
        output_id BIGINT;
      BEGIN
        FOR input_id, input_previous_output, input_output_id IN
          SELECT ci.id, ci.previous_output, ci.previous_cell_output_id
          FROM cell_inputs ci
          WHERE ci.previous_cell_output_id IS NULL AND ci.previous_output->>'tx_hash' <> '0x0000000000000000000000000000000000000000000000000000000000000000'
        LOOP
          input_tx_hash := decode(input_previous_output->>'tx_hash', 'hex');
          input_cell_index := input_previous_output->>'index';

          SELECT id INTO output_id FROM cell_outputs WHERE tx_hash = input_tx_hash AND cell_index = input_cell_index;

          IF output_id IS NOT NULL THEN
            UPDATE cell_inputs SET previous_cell_output_id = output_id WHERE id = input_id;
          END IF;
        END LOOP;
      END;
      $$;
    SQL
  end

  def down
    execute "drop PROCEDURE update_cell_inputs"
  end
end
