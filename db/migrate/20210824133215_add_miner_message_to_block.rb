class AddMinerMessageToBlock < ActiveRecord::Migration[6.1]
  def change
    add_column :blocks, :miner_message, :string
  end
end
