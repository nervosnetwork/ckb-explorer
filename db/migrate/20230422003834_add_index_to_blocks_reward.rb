class AddIndexToBlocksReward < ActiveRecord::Migration[7.0]
  def change
    add_index :blocks, :reward
  end
end
