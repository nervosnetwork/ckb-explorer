class RemovePendingRewardBlocksCountFromAddresses < ActiveRecord::Migration[6.0]
  def change
    remove_column :addresses, :pending_reward_blocks_count
  end
end
