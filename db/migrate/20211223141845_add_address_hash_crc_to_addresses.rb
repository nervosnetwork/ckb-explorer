class AddAddressHashCrcToAddresses < ActiveRecord::Migration[6.1]
  def change
    add_column :addresses, :address_hash_crc, :bigint
    add_index :addresses, :address_hash_crc
  end
end
