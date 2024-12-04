class RemoveImplicitColumnFromCellDependency < ActiveRecord::Migration[7.0]
  def change
    add_column :cell_dependencies, :block_number, :bigint
    add_column :cell_dependencies, :tx_index, :int

    add_index :cell_dependencies, %i[block_number tx_index]
  end
end
