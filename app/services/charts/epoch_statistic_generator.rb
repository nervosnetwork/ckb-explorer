module Charts
  class EpochStatisticGenerator
    def initialize(target_epoch_number)
      @target_epoch_number = target_epoch_number
    end

    def call
      return if Block.where(epoch: target_epoch_number).blank?

      blocks_count = Block.where(epoch: target_epoch_number).count
      uncles_count = Block.where(epoch: target_epoch_number).sum(:uncles_count)
      uncle_rate = uncles_count / blocks_count.to_d
      difficulty = Block.where(epoch: target_epoch_number).first.difficulty
      first_block_in_epoch = Block.where(epoch: target_epoch_number).order(:number).first
      last_lock_in_epoch = Block.where(epoch: target_epoch_number).order(:number).last
      block_time = last_lock_in_epoch.timestamp - first_block_in_epoch.timestamp
      epoch_length = Block.where(epoch: target_epoch_number).count
      hash_rate = difficulty * epoch_length / block_time

      epoch_statistic = ::EpochStatistic.find_or_create_by(epoch_number: target_epoch_number)
      epoch_statistic.update(difficulty: difficulty, uncle_rate: uncle_rate, hash_rate: hash_rate, block_time_distribution: block_time_distribution)
    end

    private

    attr_reader :target_epoch_number

    def block_time_distribution
      max_n = 19
      epoch_interval = 99
      start_epoch_number = [target_epoch_number - epoch_interval, 0].max
      epoch_numbers = (start_epoch_number..target_epoch_number).to_a
      ranges = (0..max_n).map { |n| [n, n + 1] }

      ranges.map do |range|
        millisecond_start = range[0] * 1000
        millisecond_end = range[1] * 1000
        block_count = Block.where(epoch: epoch_numbers).where("block_time > ? and block_time <= ?", millisecond_start, millisecond_end).count
        [range[1], block_count]
      end
    end
  end
end
