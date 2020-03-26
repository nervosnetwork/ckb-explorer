class AddUdtAmountToCellOutput < ActiveRecord::Migration[6.0]
  def change
    add_column :cell_outputs, :udt_amount, :decimal, precision: 40, scale: 0
  end
end
