class DropBlockTimeStatistic < ActiveRecord::Migration[7.0]
  def change
    drop_table :block_time_statistics, if_exists: true
  end
end
