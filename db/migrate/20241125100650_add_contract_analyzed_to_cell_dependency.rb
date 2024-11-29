class AddContractAnalyzedToCellDependency < ActiveRecord::Migration[7.0]
  def change
    ActiveRecord::Base.connection.execute("SET statement_timeout = 0")
    add_column :cell_dependencies, :contract_analyzed, :boolean, default: false
  end
end
