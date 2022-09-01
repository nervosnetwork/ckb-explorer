class AddTypeScriptIdIndex < ActiveRecord::Migration[6.1]
  def change
    add_index :cell_outputs, [:type_script_id, :id]
  end
end
