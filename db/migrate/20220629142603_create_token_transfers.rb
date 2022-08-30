class CreateTokenTransfers < ActiveRecord::Migration[6.1]
  def change
    create_table :token_transfers do |t|
      t.integer :item_id
      t.integer :from_id
      t.integer :to_id
      t.integer :transaction_id

      t.timestamps
    end
    add_index :token_transfers, :item_id
    add_index :token_transfers, :from_id
    add_index :token_transfers, :to_id
    add_index :token_transfers, :transaction_id
  end
end
