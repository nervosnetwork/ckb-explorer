class CreateXudtTags < ActiveRecord::Migration[7.0]
  def change
    create_table :xudt_tags do |t|
      t.integer :udt_id
      t.string :udt_type_hash
      t.string "tags", default: [], array: true

      t.timestamps
    end

    add_index :xudt_tags, :udt_id, unique: true
  end
end
