module Charts
  class DailyStatistic
    include Sidekiq::Worker
    sidekiq_options queue: "critical"

    # iterate from the creation timestamp of last daily statistic record to now day by day
    # and generate daily statistic record for each day
    def perform(datetime = nil)
      datetime ||= 1.day.ago.beginning_of_day
      last_record = ::DailyStatistic.order(created_at_unixtimestamp: :desc).first
      start_time = Time.zone.at(last_record ? last_record.created_at_unixtimestamp : Block.find_by(number: 0).timestamp / 1000)
      while start_time < datetime
        start_time += 1.day
        ActiveRecord::Base.connection.execute("SET statement_timeout = 0")
        Charts::DailyStatisticGenerator.new(start_time).call
        ActiveRecord::Base.connection.execute("RESET statement_timeout")
      end
    end
  end
end
