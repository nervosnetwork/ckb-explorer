class AddTxHashCellIndexToCellOutputs < ActiveRecord::Migration[6.1]
  def self.up
    add_column :cell_outputs, :tx_hash_cell_index, :string
    add_index :cell_outputs, :tx_hash_cell_index, using: 'hash'
  end

  def self.down
    remove_index :cell_outputs, name: "index_cell_outputs_on_tx_hash_cell_index"
    remove_column :cell_outputs, :tx_hash_cell_index
  end
end
