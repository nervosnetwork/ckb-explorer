class CreateBitcoinAddressMappings < ActiveRecord::Migration[7.0]
  def change
    create_table :bitcoin_address_mappings do |t|
      t.bigint :bitcoin_address_id
      t.bigint :ckb_address_id

      t.timestamps
    end

    add_index :bitcoin_address_mappings, %i[bitcoin_address_id ckb_address_id], name: "idex_bitcon_addresses_on_mapping", unique: true
  end
end
