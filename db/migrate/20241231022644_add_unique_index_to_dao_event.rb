class AddUniqueIndexToDaoEvent < ActiveRecord::Migration[7.0]
  def change
    add_index :dao_events, %i[block_id ckb_transaction_id cell_index event_type], unique: true, name: "index_dao_events_on_block_id_tx_id_and_index_and_type"
  end
end
