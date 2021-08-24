class AddMinerMessageToForkedBlock < ActiveRecord::Migration[6.1]
  def change
    add_column :forked_blocks, :miner_message, :string
  end
end
