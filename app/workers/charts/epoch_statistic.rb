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

      blocks_count = Block.where(epoch: target_epoch_number).count
      uncles_count = Block.where(epoch: target_epoch_number).sum(:uncles_count)
      uncle_rate = uncles_count / blocks_count.to_d
      difficulty = Block.where(epoch: target_epoch_number).first.difficulty

      ::EpochStatistic.create(epoch_number: target_epoch_number, difficulty: difficulty, uncle_rate: uncle_rate)
    end
  end
end
