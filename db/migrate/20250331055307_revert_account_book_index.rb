class RevertAccountBookIndex < ActiveRecord::Migration[7.0]
  def change
    execute("SET statement_timeout = 0;")

    remove_index :account_books, column: %i[address_id block_number tx_index]
    add_index :account_books, %i[block_number tx_index]
  end
end
