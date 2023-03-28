class CreateBlockTransaction < ActiveRecord::Migration[7.0]
  def change
    create_table :block_transactions do |t|
      t.references :block, foreign_key: { on_delete: :cascade }
      t.references :ckb_transaction, index: true, foreign_key: { on_delete: :cascade }
      t.integer :tx_index, null: false, default: 0
      t.index [:block_id, :ckb_transaction_id], name: "block_tx_alt_pk", unique: true
      t.index [:block_id, :tx_index], name: "block_tx_index", unique: true
    end
  end
end
