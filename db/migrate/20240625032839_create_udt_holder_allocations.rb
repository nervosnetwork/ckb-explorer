class CreateUdtHolderAllocations < ActiveRecord::Migration[7.0]
  def change
    create_table :udt_holder_allocations do |t|
      t.bigint :udt_id, null: false, index: true
      t.bigint :contract_id
      t.integer :ckb_holder_count, null: false, default: 0
      t.integer :btc_holder_count, null: false, default: 0

      t.timestamps
    end
  end
end
