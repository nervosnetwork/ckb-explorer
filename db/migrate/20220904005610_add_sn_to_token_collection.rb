class AddSnToTokenCollection < ActiveRecord::Migration[6.1]
  def change
    add_column :token_collections, :sn, :string
    add_index :token_collections, :sn, unique: true
  end
end
