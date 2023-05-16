# This is a materialized view
# The definition refers to db/migrate/20220705003300_create_average_block_time_by_hour_view.rb
class RollingAvgBlockTime < ApplicationRecord
  self.table_name = "rolling_avg_block_time"
  default_scope { order(timestamp: :asc) }
  def self.refresh
    connection.execute "refresh materialized view CONCURRENTLY rolling_avg_block_time "
  end
end

# == Schema Information
#
# Table name: rolling_avg_block_time
#
#  timestamp             :bigint
#  avg_block_time_daily  :decimal(, )
#  avg_block_time_weekly :decimal(, )
#
# Indexes
#
#  index_rolling_avg_block_time_on_timestamp  (timestamp) UNIQUE
#
