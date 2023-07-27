module Charts
  class ForkedEventProcessor
    include Sidekiq::Worker
    sidekiq_options queue: "critical"

    def perform
      forked_events = ForkedEvent.pending
      epoch_numbers = forked_events.pluck(:epoch_number).uniq
      epoch_numbers.each { |epoch_number| Charts::EpochStatisticGenerator.new(epoch_number).call }
      block_timestamps = forked_events.pluck(:block_timestamp).uniq
      latest_daily_statistic = ::DailyStatistic.order(:created_at_unixtimestamp).last
      if block_timestamps.any? { |block_timestamp| block_timestamp < latest_daily_statistic.block_timestamp }
        datetime = Time.zone.at(latest_daily_statistic.created_at_unixtimestamp)
        Charts::DailyStatisticGenerator.new(datetime).call
      end
      forked_events.update_all(status: "processed")
    end
  end
end
