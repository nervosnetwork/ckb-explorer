class AddLargestInfoToEpochStatistic < ActiveRecord::Migration[7.0]
  def change
    add_column :epoch_statistics, :largest_block_number, :integer
    add_column :epoch_statistics, :largest_block_size, :integer
    add_column :epoch_statistics, :largest_tx_hash, :binary
    add_column :epoch_statistics, :largest_tx_bytes, :integer
  end
end
