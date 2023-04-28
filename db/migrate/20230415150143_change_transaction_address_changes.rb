class ChangeTransactionAddressChanges < ActiveRecord::Migration[7.0]
  def change
    change_table :transaction_address_changes do |t|
      t.remove :name, type: :string
      t.remove :delta, type:  :decimal
      t.jsonb :changes, null: false, default: {}
      t.index [:address_id, :ckb_transaction_id], unique: true, name: 'tx_address_changes_alt_pk'
    end
  end
end
