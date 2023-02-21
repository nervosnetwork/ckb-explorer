class BlockTimeStatistic < ApplicationRecord
  def generate_monthly
    started_at = 30.days.ago.beginning_of_day
    ended_at = Time.current.yesterday.end_of_day

    generate(started_at, ended_at)
  end

  def generate_daily
    started_at = Time.current.yesterday.beginning_of_day
    ended_at = Time.current.yesterday.end_of_day

    generate(started_at, ended_at)
  end

  private

  def generate(started_at, ended_at)
    current_time = started_at
    values = []
    while current_time <= ended_at
      BlockTimeStatistic.connection.select_all(avg_block_time_sql(CkbUtils.time_in_milliseconds(current_time.beginning_of_day), CkbUtils.time_in_milliseconds(current_time.end_of_day))).to_a.each do |item|
        item["created_at"] = Time.current
        item["updated_at"] = Time.current

        values << item
      end

      current_time = current_time + 1.day
    end

    BlockTimeStatistic.upsert_all(values, unique_by: :stat_timestamp) if values.present?
  end

  def avg_block_time_sql(started_at, ended_at)
    <<-SQL
      select
        date_trunc('hour', to_timestamp(timestamp/1000.0)) stat_timestamp,
        avg(block_time) avg_block_time_per_hour
      from blocks
      where timestamp >= #{started_at} and timestamp <= #{ended_at}
      group by stat_timestamp
      order by stat_timestamp
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
