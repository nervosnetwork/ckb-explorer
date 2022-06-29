class CreateTokenItems < ActiveRecord::Migration[6.1]
  def change
    create_table :token_items do |t|
      t.integer :collection_id
      t.string :token_id
      t.string :name
      t.string :icon_url
      t.integer :owner_id
      t.string :metadata_url
      t.integer :cell_id

      t.timestamps
    end
    add_index :token_items, :owner_id
    add_index :token_items, :cell_id
    add_index :token_items, [:collection_id, :token_id], unique: true
  end
end
