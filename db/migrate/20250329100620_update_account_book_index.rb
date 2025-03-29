class UpdateAccountBookIndex < ActiveRecord::Migration[7.0]
  def change
    execute("SET statement_timeout = 0;")

    remove_index :account_books, column: %i[block_number tx_index]
    add_index :account_books, %i[address_id block_number tx_index],
              order: { block_number: :desc, tx_index: :desc }
  end
end
