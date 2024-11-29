class AddContractAnalyzedToCellDependency < ActiveRecord::Migration[7.0]
  def change
    add_column :cell_dependencies, :contract_analyzed, :boolean, default: false
  end
end
