class AddTimestampToAddressAndCellOutputs < ActiveRecord::Migration[6.0]
  def change
    add_column :addresses, :block_timestamp, :decimal, precision: 30, scale: 0
    add_column :cell_outputs, :block_timestamp, :decimal, precision: 30, scale: 0
  end
end
