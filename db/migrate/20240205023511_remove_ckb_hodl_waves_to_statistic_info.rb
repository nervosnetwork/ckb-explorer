class RemoveCkbHodlWavesToStatisticInfo < ActiveRecord::Migration[7.0]
  def change
    remove_columns :statistic_infos, :ckb_hodl_waves
  end
end
