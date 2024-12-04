class AddContractAnalyzedIndexToCellDependency < ActiveRecord::Migration[7.0]
  def change
    execute("SET statement_timeout = 0;")
    add_index :cell_dependencies, :contract_analyzed
    execute "RESET statement_timeout;"
  end
end
