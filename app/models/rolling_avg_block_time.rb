# This is a materialized view
# The definition refers to db/migrate/20220705003300_create_average_block_time_by_hour_view.rb
class RollingAvgBlockTime < ApplicationRecord
  self.table_name = 'rolling_avg_block_time'
  def self.refresh
    connection.execute "refresh materialized view rolling_avg_block_time CONCURRENTLY"
  end
end

# == Schema Information
#
# Table name: rolling_avg_block_time
#
#  timestamp             :integer
#  avg_block_time_daily  :decimal(, )
#  avg_block_time_weekly :decimal(, )
#
