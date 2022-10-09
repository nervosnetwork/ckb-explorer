class ChangeIndexTypeForAddresses < ActiveRecord::Migration[6.1]
  def self.up
    remove_index :addresses, name: "index_addresses_on_address_hash_crc"
    remove_index :addresses, name: "index_addresses_on_lock_hash"
    add_index :addresses, :address_hash
    add_index :addresses, :lock_hash, using: 'hash'
  end

  def self.down
    remove_index :addresses, name: "index_addresses_on_address_hash"
    add_index :addresses, :address_hash_crc
    remove_index :addresses, name: "index_addresses_on_lock_hash"
    add_index :addresses, :lock_hash
  end
end
