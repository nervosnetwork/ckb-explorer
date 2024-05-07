class RenameIndexOfBitcoinAddressMappings < ActiveRecord::Migration[7.0]
  def change
    rename_index :bitcoin_address_mappings, "idex_bitcon_addresses_on_mapping", "index_bitcoin_addresses_on_mapping"
  end
end
