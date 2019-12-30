module Charts
  class EpochStatisticGenerator
    def initialize(target_epoch_number)
      @target_epoch_number = target_epoch_number
    end

    def call
      return if Block.where(epoch: target_epoch_number).blank?

      blocks_count = Block.where(epoch: epoch_number).count
      uncles_count = Block.where(epoch: target_epoch_number).sum(:uncles_count)
      uncle_rate = uncles_count / blocks_count.to_d
      difficulty = Block.where(epoch: target_epoch_number).first.difficulty
      first_block_in_epoch = Block.where(epoch: target_epoch_number).order(:number).first
      last_lock_in_epoch = Block.where(epoch: target_epoch_number).order(:number).last
      block_time = last_lock_in_epoch.timestamp - first_block_in_epoch.timestamp
      epoch_length = Block.where(epoch: target_epoch_number).count
      hash_rate = difficulty * epoch_length / block_time

      epoch_statistic = ::EpochStatistic.find_or_create_by(epoch_number: target_epoch_number)
      epoch_statistic.update(difficulty: difficulty, uncle_rate: uncle_rate, hash_rate: hash_rate)
    end

    private
    attr_reader :target_epoch_number
  end
end
