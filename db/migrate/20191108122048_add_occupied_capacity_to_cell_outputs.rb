class AddOccupiedCapacityToCellOutputs < ActiveRecord::Migration[6.0]
  def change
    add_column :cell_outputs, :occupied_capacity, :decimal, precision: 30, scale: 0
  end
end
