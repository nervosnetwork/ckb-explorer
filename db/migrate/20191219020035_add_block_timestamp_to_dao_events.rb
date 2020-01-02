class AddBlockTimestampToDaoEvents < ActiveRecord::Migration[6.0]
  def change
    add_column :dao_events, :block_timestamp, :decimal, precision: 30, scale: 0
  end
end
