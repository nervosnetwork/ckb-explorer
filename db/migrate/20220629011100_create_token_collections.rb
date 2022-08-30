class CreateTokenCollections < ActiveRecord::Migration[6.1]
  def change
    create_table :token_collections do |t|
      t.string :standard
      t.string :name
      t.text :description
      t.integer :creator_id
      t.string :icon_url
      t.integer :items_count
      t.integer :holders_count

      t.timestamps
    end
  end
end
