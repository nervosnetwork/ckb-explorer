class AddPrimaryRewardAndSecondaryRewardToForkedBlocks < ActiveRecord::Migration[5.2]
  def change
    add_column :forked_blocks, :primary_reward, :decimal, precision: 30, scale: 0, default: 0
    add_column :forked_blocks, :secondary_reward, :decimal, precision: 30, scale: 0, default: 0
  end
end
