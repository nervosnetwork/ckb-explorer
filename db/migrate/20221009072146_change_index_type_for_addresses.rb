class ChangeIndexTypeForAddresses < ActiveRecord::Migration[6.1]
  def self.up
    remove_index :addresses, name: "index_addresses_on_address_hash_crc" rescue nil
    remove_index :addresses, name: "index_addresses_on_lock_hash" rescue nil

    add_index :addresses, :address_hash, using: "hash"
    add_index :addresses, :lock_hash, using: "hash"
    execute "alter table public.addresses add constraint unique_lock_hash unique (lock_hash);"

    remove_column :addresses, :address_hash_crc
  end

  def self.down
    add_column :addresses, :address_hash_crc, :bigint

    execute "alter table public.addresses drop constraint unique_lock_hash;"
    remove_index :addresses, name: "index_addresses_on_lock_hash"
    remove_index :addresses, name: "index_addresses_on_address_hash"

    add_index :addresses, :lock_hash
    add_index :addresses, :address_hash_crc
  end
end
