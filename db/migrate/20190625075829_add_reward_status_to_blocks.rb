class AddRewardStatusToBlocks < ActiveRecord::Migration[5.2]
  def change
    add_column :blocks, :reward_status, :integer, default: 0
  end
end
