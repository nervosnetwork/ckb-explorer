class RemoveUnusedColumnFromTypeScript < ActiveRecord::Migration[7.0]
  def change
    remove_column :type_scripts, :cell_output_id, :bigint
    remove_column :type_scripts, :script_id, :bigint
  end
end
