class CreateBtcAccountBooks < ActiveRecord::Migration[7.0]
  def change
    create_table :btc_account_books do |t|
      t.bigint :ckb_transaction_id
      t.bigint :bitcoin_address_id
    end

    add_index :btc_account_books, :bitcoin_address_id
  end
end
