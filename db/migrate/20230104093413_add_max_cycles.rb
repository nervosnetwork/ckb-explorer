class AddMaxCycles < ActiveRecord::Migration[7.0]
  def change
    add_column :epoch_statistics, :max_block_cycles, :integer
    add_column :epoch_statistics, :max_tx_cycles, :integer
    add_column :blocks, :cycles, :integer
  end
end
