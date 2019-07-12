class AddMinerLockHashToBlocks < ActiveRecord::Migration[5.2]
  def change
    add_column :blocks, :miner_lock_hash, :binary
  end
end
