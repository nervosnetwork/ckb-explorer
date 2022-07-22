# This is a materialized view
# The definition refers to db/migrate/20220705003300_create_average_block_time_by_hour_view.rb
class AverageBlockTimeByHour < ApplicationRecord
  self.table_name = 'average_block_time_by_hour'
  def self.refresh
    connection.execute "refresh materialized view average_block_time_by_hour CONCURRENTLY"
  end
end

# == Schema Information
#
# Table name: average_block_time_by_hour
#
#  hour                    :datetime
#  avg_block_time_per_hour :decimal(, )
#
