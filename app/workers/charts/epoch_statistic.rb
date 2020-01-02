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
      first_block_in_epoch = Block.where(epoch: target_epoch_number).order(:number).first
      last_lock_in_epoch = Block.where(epoch: target_epoch_number).order(:number).last
      block_time = last_lock_in_epoch.timestamp - first_block_in_epoch.timestamp
      epoch_length = Block.where(epoch: target_epoch_number).count
      hash_rate = difficulty * epoch_length / block_time

      ::EpochStatistic.create(epoch_number: target_epoch_number, difficulty: difficulty, uncle_rate: uncle_rate, hash_rate: hash_rate)
    end
  end
end
