class CreateAddressDaoTransactions < ActiveRecord::Migration[7.0]
  def change
    create_table :address_dao_transactions, id: false do |t|
      t.bigint :ckb_transaction_id, index: true
      t.bigint :address_id
    end
    add_index :address_dao_transactions, [:address_id, :ckb_transaction_id], unique: true, name: "address_dao_tx_alt_pk"
  end
end
