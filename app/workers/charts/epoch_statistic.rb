module Charts
  class EpochStatistic
    include Sidekiq::Worker
    sidekiq_options unique: :until_executed
    sidekiq_options retry: false
    sidekiq_options queue: "critical"

    def perform
      latest_epoch_number = ::EpochStatistic.order(epoch_number: :desc).pick(:epoch_number)
      target_epoch_number = latest_epoch_number + 1
      return if Block.where(epoch: target_epoch_number + 1).blank? || ::EpochStatistic.where(epoch_number: target_epoch_number).exists?

      Charts::EpochStatisticGenerator.new(target_epoch_number).call
    end
  end
end
