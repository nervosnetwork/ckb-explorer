class AddIndexToTokenCollection < ActiveRecord::Migration[6.1]
  def change
    add_index :token_collections, :cell_id
    add_index :token_items, :type_script_id
    add_index :token_collections, :type_script_id
  end
end
