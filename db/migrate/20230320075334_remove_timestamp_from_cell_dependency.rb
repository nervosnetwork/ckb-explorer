class RemoveTimestampFromCellDependency < ActiveRecord::Migration[7.0]
  def change
    remove_column :cell_dependencies, :created_at
    remove_column :cell_dependencies, :updated_at
  end
end
