class AddNrcFactoryCellIdToUdts < ActiveRecord::Migration[6.1]
  def change
    add_column :udts, :nrc_factory_cell_id, :bigint
  end
end
