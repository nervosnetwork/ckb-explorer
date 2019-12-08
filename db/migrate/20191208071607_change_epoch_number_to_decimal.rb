class ChangeEpochNumberToDecimal < ActiveRecord::Migration[6.0]
  def change
    change_column :epoch_statistics, :epoch_number, :decimal, precision: 30, scale: 0, using: "epoch_number::numeric(30,0)"
    change_column :block_statistics, :block_number, :decimal, precision: 30, scale: 0, using: "block_number::numeric(30,0)"

    add_index :epoch_statistics, :epoch_number, unique: true
    add_index :block_statistics, :block_number, unique: true
  end
end
