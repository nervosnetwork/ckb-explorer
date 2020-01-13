class AddIndexToBlockTimestampOnDaoEvents < ActiveRecord::Migration[6.0]
  def change
    add_index :dao_events, :block_timestamp
    add_index :dao_events, [:status, :event_type]
  end
end
