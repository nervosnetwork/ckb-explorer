class ChangeCellDependencyColumns < ActiveRecord::Migration[7.0]
  def change
    change_column_null :cell_dependencies, :contract_cell_id, false
    change_column_null :cell_dependencies, :ckb_transaction_id, false

    execute <<~SQL
      DELETE FROM  cell_dependencies where id in(
      SELECT id
          from (SELECT id,
               ROW_NUMBER() OVER( PARTITION BY contract_cell_id, ckb_transaction_id
              ORDER BY  id) as row_num from cell_dependencies)  t
              WHERE t.row_num > 1 )
    SQL
    add_index :cell_dependencies, [:ckb_transaction_id, :contract_cell_id], unique: true, name: "cell_deps_tx_cell_idx"
  end
end
