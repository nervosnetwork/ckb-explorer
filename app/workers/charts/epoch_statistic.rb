module Charts
  class EpochStatistic
    include Sidekiq::Worker
    sidekiq_options queue: "critical"

    def perform
      latest_epoch_number = ::EpochStatistic.order(epoch_number: :desc).pick(:epoch_number) || 0
      target_epoch_number = latest_epoch_number + 1
      Charts::EpochStatisticGenerator.new(target_epoch_number).call
    end
  end
end
