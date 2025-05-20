class CreateSsriContracts < ActiveRecord::Migration[7.0]
  def change
    create_table :ssri_contracts do |t|
      t.bigint :contract_id
      t.string :methods, array: true, default: []
      t.boolean :is_udt
      t.binary :code_hash
      t.string :hash_type

      t.timestamps
    end
    add_index :ssri_contracts, :contract_id, unique: true
  end
end
