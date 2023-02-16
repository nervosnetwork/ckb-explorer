class CreateUdtAddressTransactions < ActiveRecord::Migration[7.0]
  def change
    create_table :udt_address_transactions do |t|
      t.bigint :udt_address_id
      t.bigint :ckb_transaction_id

      t.timestamps null: false
    end
  end
end
