class AddCkbHodlWavesToDailyStatistic < ActiveRecord::Migration[7.0]
  def change
    add_column :daily_statistics, :ckb_hodl_wave, :jsonb
  end
end
