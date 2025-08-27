class AddIndexToBitcoinVoutForCellOutputId < ActiveRecord::Migration[7.0]
  def change
    add_index :bitcoin_vouts, :cell_output_id
  end
end
