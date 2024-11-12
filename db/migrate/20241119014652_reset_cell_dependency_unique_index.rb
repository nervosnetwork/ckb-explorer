class ResetCellDependencyUniqueIndex < ActiveRecord::Migration[7.0]
  def change
    execute "SET statement_timeout = 3600000"
    remove_index :cell_dependencies, column: %i[ckb_transaction_id contract_cell_id]

    add_index :cell_dependencies, %i[ckb_transaction_id contract_cell_id dep_type], name: "index_cell_dependencies_on_tx_id_and_cell_id_and_dep_type", unique: true
  end
end
