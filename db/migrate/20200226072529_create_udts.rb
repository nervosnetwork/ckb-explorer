class CreateUdts < ActiveRecord::Migration[6.0]
  def change
    create_table :udts do |t|
      t.binary :code_hash
      t.string :hash_type
      t.string :args
      t.string :type_hash
      t.string :full_name
      t.string :symbol
      t.integer :decimal
      t.string :description
      t.string :icon_file
      t.string :operator_website
      t.decimal :addresses_count, precision: 30, default: 0
      t.decimal :total_amount, precision: 40, default: 0
      t.integer :udt_type
      t.boolean :published, default: false

      t.timestamps
    end

    add_index :udts, :type_hash, unique: true
  end
end
