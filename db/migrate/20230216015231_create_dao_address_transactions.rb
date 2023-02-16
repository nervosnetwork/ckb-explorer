class CreateDaoAddressTransactions < ActiveRecord::Migration[7.0]
  def change
    create_table :dao_address_transactions do |t|
      t.bigint :dao_address_id
      t.bigint :ckb_transaction_id

      t.timestamps null: false
    end
  end
end
