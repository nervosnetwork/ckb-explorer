module Charts
  class EpochStatistic
    include Sidekiq::Worker
    sidekiq_options unique: :until_executed
    sidekiq_options retry: false
    sidekiq_options queue: "critical"

    def perform
      latest_epoch_number = ::EpochStatistic.order(epoch_number: :desc).pick(:epoch_number) || 0
      target_epoch_number = latest_epoch_number + 1
      block_in_target_epoch = Block.where(epoch: target_epoch_number).first
      if block_in_target_epoch.present? && Block.where(epoch: target_epoch_number).count == block_in_target_epoch.length
        Charts::EpochStatisticGenerator.new(target_epoch_number).call
      end
    end
  end
end
