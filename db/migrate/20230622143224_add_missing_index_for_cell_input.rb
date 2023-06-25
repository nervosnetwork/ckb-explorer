class AddMissingIndexForCellInput < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!
  def change
    CellInput.fill_missing_index
  end
end
