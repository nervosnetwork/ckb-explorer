class AddSeparateIndexOnStatusToCellOutputs < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def change
    add_index :cell_outputs, :status, algorithm: :concurrently
  end
end
