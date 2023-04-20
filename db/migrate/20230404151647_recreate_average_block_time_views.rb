class RecreateAverageBlockTimeViews < ActiveRecord::Migration[7.0]
  def self.up
    execute <<~SQL
      CREATE MATERIALIZED VIEW IF NOT EXISTS average_block_time_by_hour
      AS
       SELECT (blocks."timestamp" / 3600000)::bigint AS hour,
          avg(blocks.block_time) AS avg_block_time_per_hour
         FROM blocks
        GROUP BY (blocks."timestamp" / 3600000)::bigint
      WITH NO DATA;
    SQL

    execute <<~SQL
      CREATE MATERIALIZED VIEW IF NOT EXISTS rolling_avg_block_time
      TABLESPACE pg_default
      AS
       SELECT (average_block_time_by_hour.hour * 3600)::bigint as timestamp,
          avg(average_block_time_by_hour.avg_block_time_per_hour) OVER (ORDER BY average_block_time_by_hour.hour ROWS BETWEEN 24 PRECEDING AND CURRENT ROW) AS avg_block_time_daily,
          avg(average_block_time_by_hour.avg_block_time_per_hour) OVER (ORDER BY average_block_time_by_hour.hour ROWS BETWEEN (7 * 24) PRECEDING AND CURRENT ROW) AS avg_block_time_weekly
         FROM average_block_time_by_hour
      WITH NO DATA;
    SQL

    add_index :average_block_time_by_hour, :hour, unique: true
    add_index :rolling_avg_block_time, :timestamp, unique: true
  end

  def self.down
    execute "DROP MATERIALIZED VIEW IF EXISTS rolling_avg_block_time, average_block_time_by_hour"
  end
end
