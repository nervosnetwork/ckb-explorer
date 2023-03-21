class CreateAddressUdtTransactions < ActiveRecord::Migration[7.0]
  def change
    create_table :address_udt_transactions, id: false do |t|
      t.bigint :ckb_transaction_id, index: true
      t.bigint :address_id
    end
    add_index :address_udt_transactions, [:address_id, :ckb_transaction_id], unique: true, name: "address_udt_tx_alt_pk"
  end
end
