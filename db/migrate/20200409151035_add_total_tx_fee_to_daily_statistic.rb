class AddTotalTxFeeToDailyStatistic < ActiveRecord::Migration[6.0]
  def change
    add_column :daily_statistics, :total_tx_fee, :decimal, precision: 30, scale: 0
  end
end
