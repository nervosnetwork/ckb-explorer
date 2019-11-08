class AddDataSizeToCellOutput < ActiveRecord::Migration[6.0]
  def change
    add_column :cell_outputs, :data_size, :integer
  end
end
