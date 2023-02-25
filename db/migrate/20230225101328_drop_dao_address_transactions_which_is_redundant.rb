class DropDaoAddressTransactionsWhichIsRedundant < ActiveRecord::Migration[7.0]
  def self.up
    drop_table :dao_address_transactions
  end

  def self.down
    create_table :dao_address_transactions do |t|
      t.bigint :dao_address_id
      t.bigint :ckb_transaction_id

      t.timestamps null: false
    end
  end
end
