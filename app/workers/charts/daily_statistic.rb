module Charts
  class DailyStatistic
    include Sidekiq::Worker
    sidekiq_options queue: "critical", backtrace: 20

    # iterate from the creation timestamp of last daily statistic record to now day by day
    # and generate daily statistic record for each day
    def perform(datetime = nil)
      if datetime.present?
        Charts::DailyStatisticGenerator.new(datetime).call
      else
        process_multiple_days
      end

    end

    # process from "last_record_date + 1.day", to "yesterday"
    def process_multiple_days
      last_record = ::DailyStatistic.order(created_at_unixtimestamp: :desc).first

      last_record_date = nil
      if last_record.present?
        last_record_date = DateTime.strptime(last_record.created_at_unixtimestamp.to_s, '%s')
      else
        last_record_date = DateTime.strptime((Block.first.timestamp / 1000).to_s, '%s')
      end

      from = last_record_date + 1.day
      to = DateTime.now - 1.day
      dates = from.step(to, 1).to_a

      Rails.logger.info "== in DailyStatistic worker, processing dates: #{dates}"
      dates.each do |date|
        Charts::DailyStatisticGenerator.new(date.to_time).call
      end
    end
  end
end
