class AddBlockTimestampToUdts < ActiveRecord::Migration[6.0]
  def change
    add_column :udts, :block_timestamp, :decimal, precision: 30
  end
end
