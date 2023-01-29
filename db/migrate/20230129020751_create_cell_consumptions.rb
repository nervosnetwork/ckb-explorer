class CreateCellConsumptions < ActiveRecord::Migration[7.0]
  def change
    create_table :cell_consumptions do |t|

      t.timestamps
    end
  end
end
