class AddContainedAddressIdsIndexToCkbTransactions < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!
  def change
    execute "create extension btree_gin" rescue nil
    add_index :ckb_transactions, [:contained_address_ids, :id], using: :gin, algorithm: :concurrently
  end
end
