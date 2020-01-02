module Charts
  class DailyStatistic
    include Sidekiq::Worker
    sidekiq_options unique: :until_executed
    sidekiq_options retry: false
    sidekiq_options queue: "critical"

    def perform(datetime = nil)
      Charts::DailyStatisticGenerator.new(datetime).call
    end
  end
end
