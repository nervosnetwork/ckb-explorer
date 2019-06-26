class AddPendingRewardBlocksCountToAddresses < ActiveRecord::Migration[5.2]
  def change
    add_column :addresses, :pending_reward_blocks_count, :integer, default: 0
  end
end
