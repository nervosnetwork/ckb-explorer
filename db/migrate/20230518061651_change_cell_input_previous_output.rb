class ChangeCellInputPreviousOutput < ActiveRecord::Migration[7.0]
  def change
    change_table :cell_inputs, bulk: true do |t|
      t.binary :previous_tx_hash
      t.integer :previous_index
    end
    execute <<~SQL
      UPDATE cell_inputs
      SET previous_tx_hash = decode(substring(previous_output ->> 'tx_hash',3), 'hex') ,
      previous_index = ('x' || lpad(substring(previous_output ->> 'index' from 3), 8, '0'))::bit(32)::int
      where previous_cell_output_id is null and previous_output is not null
    SQL
    add_index :cell_inputs, [:previous_tx_hash, :previous_index]
    remove_column :cell_inputs, :previous_output
  end
end
