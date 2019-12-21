class AddLiveCellsCountToAddresses < ActiveRecord::Migration[6.0]
  def change
    add_column :addresses, :live_cells_count, :decimal, precision: 30, scale: 0, default: 0
  end
end
