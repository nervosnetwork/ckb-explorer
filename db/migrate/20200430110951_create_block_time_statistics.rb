class CreateBlockTimeStatistics < ActiveRecord::Migration[6.0]
  def change
    create_table :block_time_statistics do |t|
      t.decimal :stat_timestamp, precision: 30
      t.decimal :avg_block_time_per_hour

      t.timestamps
    end

    add_index :block_time_statistics, :stat_timestamp, unique: true
  end
end
