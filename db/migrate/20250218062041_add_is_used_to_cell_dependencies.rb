class AddIsUsedToCellDependencies < ActiveRecord::Migration[7.0]
  def change
    remove_column :cell_dependencies, :contract_id, :bigint
    remove_column :cell_dependencies, :script_id, :bigint
    remove_column :cell_dependencies, :implicit, :boolean

    add_column :cell_dependencies, :is_used, :boolean, default: true
  end
end
