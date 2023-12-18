class AddCkbHodlWavesToStatisticInfo < ActiveRecord::Migration[7.0]
  def change
    add_column :statistic_infos, :ckb_hodl_waves, :jsonb
  end
end
