class AddDataHashToCellOutput < ActiveRecord::Migration[7.0]
  def change
    add_column :cell_outputs, :data_hash, :binary
    add_index :cell_outputs, :data_hash, using: :hash
  end
end
