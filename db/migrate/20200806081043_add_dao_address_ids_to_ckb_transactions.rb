class AddDaoAddressIdsToCkbTransactions < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def change
    add_column :ckb_transactions, :dao_address_ids, :bigint, array: true, default: []
    add_column :ckb_transactions, :udt_address_ids, :bigint, array: true, default: []

    add_index :ckb_transactions, :dao_address_ids, using: :gin, algorithm: :concurrently
    add_index :ckb_transactions, :udt_address_ids, using: :gin, algorithm: :concurrently
  end
end
