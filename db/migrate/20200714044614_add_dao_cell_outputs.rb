class AddDaoCellOutputs < ActiveRecord::Migration[6.0]
  def change
    add_column :cell_outputs, :dao, :string
  end
end
