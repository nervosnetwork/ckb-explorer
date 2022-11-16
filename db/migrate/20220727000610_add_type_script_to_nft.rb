class AddTypeScriptToNFT < ActiveRecord::Migration[6.1]
  def change
    add_column :token_collections, :type_script_id, :integer
    add_column :token_items, :type_script_id, :integer
  end
end
