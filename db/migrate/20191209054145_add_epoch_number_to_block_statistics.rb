class AddEpochNumberToBlockStatistics < ActiveRecord::Migration[6.0]
  def change
    add_column :block_statistics, :epoch_number, :decimal, precision: 30, scale: 0
  end
end
