class AddConsumedBlockTimestampToCellOutputs < ActiveRecord::Migration[6.0]
  def change
    add_column :cell_outputs, :consumed_block_timestamp, :decimal, precision: 30, scale: 0
  end
end
