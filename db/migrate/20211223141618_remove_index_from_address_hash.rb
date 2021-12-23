class RemoveIndexFromAddressHash < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!
  def change
    remove_index :addresses, :address_hash, algorithm: :concurrently
  end
end
