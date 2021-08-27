class ChangeConsumedBlockTimestampDefaultValueToZero < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def change
    change_column_default :cell_outputs, :consumed_block_timestamp, from: nil, to: 0
    add_index :cell_outputs, :block_timestamp, if_not_exists: true, algorithm: :concurrently
    add_index :cell_outputs, :consumed_block_timestamp, if_not_exists: true, algorithm: :concurrently
  end
end
