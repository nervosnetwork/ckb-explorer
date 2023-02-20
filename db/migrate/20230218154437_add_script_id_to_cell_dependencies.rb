class AddScriptIdToCellDependencies < ActiveRecord::Migration[7.0]
  def change
    add_column :cell_dependencies, :script_id, :bigint

  end
end
