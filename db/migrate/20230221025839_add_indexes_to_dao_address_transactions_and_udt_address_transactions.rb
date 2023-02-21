class AddIndexesToDaoAddressTransactionsAndUdtAddressTransactions < ActiveRecord::Migration[7.0]
  def change
    add_index :udt_address_transactions, :udt_address_id
    add_index :udt_address_transactions, :ckb_transaction_id
    add_index :dao_address_transactions, :ckb_transaction_id
    add_index :dao_address_transactions, :dao_address_id
  end
end
