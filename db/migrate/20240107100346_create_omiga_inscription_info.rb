class CreateOmigaInscriptionInfo < ActiveRecord::Migration[7.0]
  def change
    create_table :omiga_inscription_infos do |t|
      t.binary :code_hash
      t.string :hash_type
      t.string :args
      t.decimal :decimal
      t.string :name
      t.string :symbol
      t.string :udt_hash
      t.decimal :expected_supply
      t.decimal :mint_limit
      t.integer :mint_status
      t.bigint :udt_id

      t.timestamps
      t.index ["udt_hash"], name: "index_omiga_inscription_infos_on_udt_hash", unique: true
    end
  end
end
