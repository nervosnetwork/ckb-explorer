class CreateUdtTransactions < ActiveRecord::Migration[7.0]
  def change
    create_table :udt_transactions, id: false do |t|
      t.references :udt, foreign_key: { on_delete: :cascade }
      t.references :ckb_transaction, index: true, foreign_key: { on_delete: :cascade }
      t.index [:udt_id, :ckb_transaction_id], name: "pk", unique: true
    end
  end
end
