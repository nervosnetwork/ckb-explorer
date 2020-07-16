class AddTagsAddressIdsAndUdtTypeHashesToCkbTransaction < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def change
    add_column :ckb_transactions, :contained_address_ids, :bigint, array: true, default: []
    add_column :ckb_transactions, :tags, :string, array: true, default: []
    add_column :ckb_transactions, :contained_udt_ids, :bigint, array: true, default: []

    add_index :ckb_transactions, :contained_address_ids, using: :gin, algorithm: :concurrently
    add_index :ckb_transactions, :tags, using: :gin, algorithm: :concurrently
    add_index :ckb_transactions, :contained_udt_ids, using: :gin, algorithm: :concurrently
  end
end
