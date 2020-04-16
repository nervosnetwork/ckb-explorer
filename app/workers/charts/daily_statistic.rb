module Charts
  class DailyStatistic
    include Sidekiq::Worker
    sidekiq_options queue: "critical", backtrace: 20

    def perform(datetime = nil)
      Charts::DailyStatisticGenerator.new(datetime).call
    end
  end
end
