class ChangeDeployedBlockTimestampFromContracts < ActiveRecord::Migration[7.0]
  def change
    change_column :contracts, :deployed_block_timestamp, :decimal, precision: 20, scale: 0
  end
end
