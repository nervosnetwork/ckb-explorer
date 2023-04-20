class CreateTransactionAddressChanges < ActiveRecord::Migration[7.0]
  def change
    create_table :transaction_address_changes do |t|
      t.bigint :ckb_transaction_id, null: false
      t.bigint :address_id, null: false
      t.string :name, null: false
      t.decimal :delta, null: false, default: 0
      t.index :ckb_transaction_id
      t.index [:address_id, :ckb_transaction_id, :name], unique: true, name: "tx_address_changes_alt_pk"
    end
  end
end
