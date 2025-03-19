class AddIncomeToAccountBook < ActiveRecord::Migration[7.0]
  def change
     execute("SET statement_timeout = 0;")
     add_column :account_books, :income, :decimal, precision: 30
     add_column :account_books, :block_number, :bigint
     add_column :account_books, :tx_index, :integer

     add_index :account_books, [:block_number, :tx_index]
  end
end
