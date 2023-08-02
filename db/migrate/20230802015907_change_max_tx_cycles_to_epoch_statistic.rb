class ChangeMaxTxCyclesToEpochStatistic < ActiveRecord::Migration[7.0]
  def change
    change_column :epoch_statistics, :max_tx_cycles, :bigint
  end
end
