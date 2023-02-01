class CreateContracts < ActiveRecord::Migration[7.0]
  def change
    create_table :contracts do |t|
      t.binary :code_hash
      t.string :hash_type
      t.string :deployed_args
      t.string :role
      t.string :name
      t.string :symbol
      t.boolean :verified, default: false

      t.timestamps null: false
    end
  end
end
