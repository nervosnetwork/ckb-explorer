class AddTypeHashToCellOutput < ActiveRecord::Migration[6.0]
  def change
    add_column :cell_outputs, :type_hash, :string
  end
end
