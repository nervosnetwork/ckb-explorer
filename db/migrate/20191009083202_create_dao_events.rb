class CreateDaoEvents < ActiveRecord::Migration[6.0]
  def change
    create_table :dao_events do |t|
      t.bigint :block_id
      t.bigint :ckb_transaction_id
      t.bigint :address_id
      t.bigint :contract_id
      t.integer :event_type, limit: 1
      t.decimal :value, precision: 30, default: "0"
      t.integer :status, limit: 1, default: "0"

      t.timestamps
    end

    add_index :dao_events, :block_id
  end
end
