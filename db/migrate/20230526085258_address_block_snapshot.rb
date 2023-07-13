class AddressBlockSnapshot < ActiveRecord::Migration[7.0]
  def change
    create_table :address_block_snapshots do |t|
      t.belongs_to :address
      t.belongs_to :block
      t.bigint :block_number
      t.jsonb :final_state

      t.index [:block_id, :address_id], unique: true
    end
  end
end
