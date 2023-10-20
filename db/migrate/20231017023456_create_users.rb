class CreateUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :users do |t|
      t.string :uuid, limit: 36
      t.string :identifier
      t.string :name

      t.timestamps
    end

    add_index :users, :uuid, unique: true
    add_index :users, :identifier, unique: true
  end
end
