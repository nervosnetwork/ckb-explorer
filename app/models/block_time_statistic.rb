class BlockTimeStatistic < ApplicationRecord
  def generate
    started_at = time_in_milliseconds(30.days.ago.beginning_of_day)
    ended_at = time_in_milliseconds(30.days.ago.end_of_day) - 1
    <<-SQL
      select
        date_trunc('hour', to_timestamp(timestamp/1000.0)) datetime,
        avg(block_time) avg_time
      from blocks
      where timestamp >= #{started_at} and timestamp <= #{ended_at}
      group by 1
      order by 1
    SQL
  end
end

# == Schema Information
#
# Table name: block_time_statistics
#
#  id                      :bigint           not null, primary key
#  stat_timestamp          :decimal(30, )
#  avg_block_time_per_hour :decimal(, )
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#
# Indexes
#
#  index_block_time_statistics_on_stat_timestamp  (stat_timestamp) UNIQUE
#
