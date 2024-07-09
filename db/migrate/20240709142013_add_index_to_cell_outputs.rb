class AddIndexToCellOutputs < ActiveRecord::Migration[7.0]
  def change
    add_index :cell_outputs, :address_id
    add_index :cell_outputs, :block_id
    add_index :cell_outputs, :consumed_by_id
    add_index :cell_outputs, :lock_script_id
    add_index :cell_outputs, :type_script_id
    add_index :cell_outputs, %i[ckb_transaction_id cell_index status], unique: true, name: "index_cell_outputs_on_tx_id_and_cell_index_and_status"
    add_index :cell_outputs, %i[tx_hash cell_index status], unique: true, name: "index_cell_outputs_on_tx_hash_and_cell_index_and_status"
    add_index :cell_outputs, :block_timestamp
    add_index :cell_outputs, :consumed_block_timestamp
  end
end
