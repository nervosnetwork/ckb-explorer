class AddPrimaryRewardAndSecondaryRewardToBlocks < ActiveRecord::Migration[5.2]
  def change
    add_column :blocks, :primary_reward, :decimal, precision: 30, scale: 0, default: 0
    add_column :blocks, :secondary_reward, :decimal, precision: 30, scale: 0, default: 0
  end
end
