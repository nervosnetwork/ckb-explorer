class AddReceivedTxFeeStatusToBlocks < ActiveRecord::Migration[5.2]
  def change
    add_column :blocks, :received_tx_fee_status, :integer, default: 0
  end
end
