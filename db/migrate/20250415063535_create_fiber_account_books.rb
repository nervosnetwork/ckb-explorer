class CreateFiberAccountBooks < ActiveRecord::Migration[7.0]
  def change
    create_table :fiber_account_books do |t|
      t.bigint :fiber_graph_channel_id
      t.bigint :ckb_transaction_id
      t.bigint :address_id
    end

    add_index :fiber_account_books, %i[address_id ckb_transaction_id], unique: true
    add_index :fiber_account_books, :ckb_transaction_id
  end
end
