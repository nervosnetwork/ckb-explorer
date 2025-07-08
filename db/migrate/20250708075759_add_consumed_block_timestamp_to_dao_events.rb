class AddConsumedBlockTimestampToDaoEvents < ActiveRecord::Migration[7.0]
  def change
    rename_column :dao_events, :withdrawn_transaction_id, :consumed_transaction_id
    add_column :dao_events, :consumed_block_timestamp, :decimal, precision: 20, scale: 0
    add_column :dao_events, :cell_output_id, :bigint
  end
end
