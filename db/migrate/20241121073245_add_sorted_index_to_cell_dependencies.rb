class AddSortedIndexToCellDependencies < ActiveRecord::Migration[7.0]
  def change
    ActiveRecord::Base.connection.execute("SET statement_timeout = 0")

    remove_index :cell_dependencies, column: :contract_cell_id
    add_index :cell_dependencies, %i[contract_cell_id block_number tx_index],
              order: { block_number: :desc, tx_index: :desc },
              name: "index_on_cell_dependencies_contract_cell_block_tx"
  end
end
