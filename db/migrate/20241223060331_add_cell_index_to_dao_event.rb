class AddCellIndexToDaoEvent < ActiveRecord::Migration[7.0]
  def change
    add_column :dao_events, :withdrawn_transaction_id, :bigint
    add_column :dao_events, :cell_index, :integer
  end
end
