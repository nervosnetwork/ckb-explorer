class DropGlobalStatistic < ActiveRecord::Migration[7.0]
  def change
    drop_table :global_statistics, if_exists: true
  end
end
