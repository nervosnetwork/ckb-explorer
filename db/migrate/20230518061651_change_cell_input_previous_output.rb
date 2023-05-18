class ChangeCellInputPreviousOutput < ActiveRecord::Migration[7.0]
  def change
    add_column :cell_inputs, :previous_tx_hash, :binary
    execute <<~SQL
      UPDATE cell_inputs
      SET previous_tx_hash = decode(substring(previous_output ->> 'tx_hash',3), 'hex') where previous_cell_output_id is null and previous_output is not null
    SQL
    add_index :cell_inputs, :previous_tx_hash
    remove_column :cell_inputs, :previous_output
  end
end
