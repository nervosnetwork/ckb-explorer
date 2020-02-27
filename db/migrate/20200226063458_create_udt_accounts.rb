class CreateUdtAccounts < ActiveRecord::Migration[6.0]
  def change
    create_table :udt_accounts do |t|
      t.integer :udt_type
      t.string :full_name
      t.string :symbol
      t.integer :decimal
      t.decimal :amount, precision: 40
      t.boolean :published, default: false
      t.references :address

      t.timestamps
    end
  end
end
