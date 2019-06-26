class AddReceivedTxFeeToBlocks < ActiveRecord::Migration[5.2]
  def change
    add_column :blocks, :received_tx_fee, :decimal, precision: 30, scale: 0, default: 0
  end
end
