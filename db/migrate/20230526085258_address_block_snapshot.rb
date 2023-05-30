class AddressBlockSnapshot < ActiveRecord::Migration[7.0]
  def change
    create_table :address_block_snapshots do |t|
      t.belongs_to :address
      t.belongs_to :block
      t.bigint :block_number
      t.decimal :balance, precision: 30, scale: 0
      t.decimal :balance_occupied, precision: 30, scale: 0
      t.bigint :ckb_transactions_count
      t.bigint :dao_transactions_count
      t.bigint :live_cells_count

      t.index [:block_id, :address_id], unique: true
    end
  end
end
