class CreateUdtAccounts < ActiveRecord::Migration[6.0]
  def change
    create_table :udt_accounts do |t|
      t.integer :udt_type
      t.string :full_name
      t.string :symbol
      t.integer :decimal
      t.decimal :amount, precision: 40, default: 0
      t.boolean :published, default: false
      t.binary :code_hash
      t.string :type_hash
      t.references :address

      t.timestamps
    end

    add_index :udt_accounts, [:type_hash, :address_id], unique: true
  end
end
