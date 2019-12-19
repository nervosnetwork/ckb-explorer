class AddMinedBlocksCountToAddresses < ActiveRecord::Migration[6.0]
  def change
    add_column :addresses, :mined_blocks_count, :integer, default: 0
  end
end
