class ChangeBlockCycles < ActiveRecord::Migration[7.0]
  def change
    change_column :blocks, :cycles, :bigint
    change_column :epoch_statistics, :max_block_cycles, :bigint
  end
end
