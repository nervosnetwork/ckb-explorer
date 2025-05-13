class AddBlockTimestampToContracts < ActiveRecord::Migration[7.0]
  def change
    add_column :contracts, :deployed_block_timestamp, :bigint
  end
end
