class ChangeCellDependencyColumns < ActiveRecord::Migration[7.0]
  def change
    change_column_null :cell_dependencies, :contract_cell_id, false
    change_column_null :cell_dependencies, :ckb_transaction_id, false
    execute <<-SQL
      DELETE FROM cell_dependencies
      WHERE  id NOT IN (SELECT Min(id)
                  FROM   cell_dependencies
                  GROUP  BY ckb_transaction_id, contract_cell_id)
    SQL
    add_index :cell_dependencies, [:ckb_transaction_id, :contract_cell_id], unique: true
  end
end
