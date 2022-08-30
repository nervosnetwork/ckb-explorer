class AddSymbolToTokenCollection < ActiveRecord::Migration[6.1]
  def change
    add_column :token_collections, :symbol, :string
    add_column :token_collections, :cell_id, :integer
    add_column :token_collections, :verified, :boolean, default: false
  end
end
