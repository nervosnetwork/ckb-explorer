class AddStatisticsToContract < ActiveRecord::Migration[7.0]
  def change
    add_column :contracts, :ckb_transactions_count, :decimal, precision: 30, default: 0
    add_column :contracts, :deployed_cells_count, :decimal, precision: 30, default: 0
    add_column :contracts, :referring_cells_count, :decimal, precision: 30, default: 0
    add_column :contracts, :total_deployed_cells_capacity, :decimal, precision: 30, default: 0
    add_column :contracts, :total_referring_cells_capacity, :decimal, precision: 30, default: 0
  end
end
