class AddIndexToCellInput < ActiveRecord::Migration[7.0]
  def change
    add_column :cell_inputs, :index, :integer
  end
end
