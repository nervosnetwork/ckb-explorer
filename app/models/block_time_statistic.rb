class BlockTimeStatistic < ApplicationRecord
  def generate_monthly
    started_at = 30.days.ago.beginning_of_day
    ended_at = 30.days.ago.end_of_day

    generate(started_at, ended_at)
  end

  def generate_daily
    started_at = Time.current.yesterday.beginning_of_day
    ended_at = Time.current.yesterday.end_of_day

    generate(started_at, ended_at)
  end

  private

  def generate(started_at, ended_at)
    values =
      (started_at..ended_at).map do |datetime|
        BlockTimeStatistic.connection.select_all(avg_block_time_sql).to_a.map do |item|
          item["created_at"] = Time.current
          item["updated_at"] = Time.current
          item
        end
      end

    BlockTimeStatistic.upsert_all(values, unique_by: :stat_timestamp)
  end

  def avg_block_time_sql(started_at, ended_at)
    <<-SQL
      select
        date_trunc('hour', to_timestamp(timestamp/1000.0)) stat_timestamp,
        avg(block_time) avg_block_time_per_hour
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
