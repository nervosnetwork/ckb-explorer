class AddBlockIdToCellInputs < ActiveRecord::Migration[5.2]
  def change
    add_column :cell_inputs, :block_id, :decimal, precision: 30, scale: 0

    add_index :cell_inputs, :block_id
  end
end
