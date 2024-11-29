class AddContractAnalyzedIndexToCellDependency < ActiveRecord::Migration[7.0]
  def change
    add_index :cell_dependencies, :contract_analyzed
  end
end
