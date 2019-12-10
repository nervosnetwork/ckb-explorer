class RenameCellCountToCellsCountOnBlockStatistics < ActiveRecord::Migration[6.0]
  def change
    rename_column :block_statistics, :live_cell_count, :live_cells_count
    rename_column :block_statistics, :dead_cell_count, :dead_cells_count
  end
end
