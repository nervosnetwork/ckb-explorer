class AddIndexesToUdtAddressTransactions < ActiveRecord::Migration[7.0]
  def change
    add_index :udt_address_transactions, :ckb_transaction_id
    add_index :udt_address_transactions, [:udt_address_id, :ckb_transaction_id], name: 'index_udt_address_transactions_on_tx_id_and_udt_address_id'
  end
end
