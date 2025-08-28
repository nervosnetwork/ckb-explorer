class AddBlockNumberIndexToCkbTransactions < ActiveRecord::Migration[7.0]
  def change
    table_name = :ckb_transactions
    column_name = :block_number
    index_name = "index_#{table_name}_on_#{column_name}".to_sym
    unless index_exists?(table_name, column_name)
      execute('SET statement_timeout = 0;')
      add_index table_name, column_name, name: index_name
    end
  end
end
