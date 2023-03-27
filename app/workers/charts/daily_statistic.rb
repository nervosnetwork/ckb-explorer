module Charts
  class DailyStatistic
    include Sidekiq::Worker
    sidekiq_options queue: "critical", backtrace: 20

    def perform(datetime = nil)
      # iterate from the creation timestamp of last daily statistic record to now day by day
      # and generate daily statistic record for each day

      datetime ||= Time.now
      last_record = ::DailyStatistic.order(created_at_unixtimestamp: :desc).first
      if last_record.present?
        start_date = Time.at(last_record.created_at_unixtimestamp) + 1.day
      else
        start_date = datetime - 1.day
      end
      puts "start_date: #{start_date}, datetime: #{datetime}"
      records = []
      while start_date < datetime
        ApplicationRecord.benchmark("#{start_date} generation") do
          records << Charts::DailyStatisticGenerator.new(start_date).call
        end
        start_date += 1.day
      end
      records
    end
  end
end
