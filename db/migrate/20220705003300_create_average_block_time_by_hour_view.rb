class CreateAverageBlockTimeByHourView < ActiveRecord::Migration[6.1]
  def self.up
    execute <<-sql
CREATE MATERIALIZED VIEW IF NOT EXISTS average_block_time_by_hour
AS
 SELECT date_trunc('hour'::text, to_timestamp((blocks."timestamp" / 1000.0)::double precision)) AS hour,
    avg(blocks.block_time) AS avg_block_time_per_hour
   FROM blocks
  GROUP BY (date_trunc('hour'::text, to_timestamp((blocks."timestamp" / 1000.0)::double precision)))
WITH DATA;
sql

    execute <<-sql
CREATE MATERIALIZED VIEW IF NOT EXISTS rolling_avg_block_time
TABLESPACE pg_default
AS
 SELECT EXTRACT(EPOCH FROM average_block_time_by_hour.hour)::integer as timestamp,
    avg(average_block_time_by_hour.avg_block_time_per_hour) OVER (ORDER BY average_block_time_by_hour.hour ROWS BETWEEN 24 PRECEDING AND CURRENT ROW) AS avg_block_time_daily,
    avg(average_block_time_by_hour.avg_block_time_per_hour) OVER (ORDER BY average_block_time_by_hour.hour ROWS BETWEEN (7 * 24) PRECEDING AND CURRENT ROW) AS avg_block_time_weekly
   FROM average_block_time_by_hour
WITH DATA;
sql
  end

  def self.down
    execute "DROP MATERIALIZED VIEW IF EXISTS rolling_avg_block_time, average_block_time_by_hour"
  end
end
