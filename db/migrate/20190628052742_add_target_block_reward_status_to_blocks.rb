class AddTargetBlockRewardStatusToBlocks < ActiveRecord::Migration[5.2]
  def change
    add_column :blocks, :target_block_reward_status, :integer, default: 0
  end
end
