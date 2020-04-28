module Charts
  class EpochStatisticGenerator
    def initialize(target_epoch_number)
      @target_epoch_number = target_epoch_number
    end

    def call
      return if Block.where(epoch: target_epoch_number).blank?

      return unless Block.where(epoch: target_epoch_number).count == Block.where(epoch: target_epoch_number).order(:number)[0].length

      blocks_count = Block.where(epoch: target_epoch_number).count
      uncles_count = Block.where(epoch: target_epoch_number).sum(:uncles_count)
      uncle_rate = uncles_count / blocks_count.to_d
      difficulty = Block.where(epoch: target_epoch_number).order(:number)[0].difficulty
      first_block_in_epoch = Block.where(epoch: target_epoch_number).order(:number).select(:timestamp)[0]
      last_lock_in_epoch = Block.where(epoch: target_epoch_number).order(number: :desc).select(:timestamp)[0]
      epoch_time = last_lock_in_epoch.timestamp - first_block_in_epoch.timestamp
      epoch_length = Block.where(epoch: target_epoch_number).order(:number)[0].length
      hash_rate = difficulty * epoch_length / epoch_time

      epoch_statistic = ::EpochStatistic.find_or_create_by(epoch_number: target_epoch_number)
      epoch_statistic.update(difficulty: difficulty, uncle_rate: uncle_rate, hash_rate: hash_rate,
                             epoch_time: epoch_time, epoch_time_distribution: epoch_time_distribution,
                             epoch_length: epoch_length, epoch_length_distribution: epoch_length_distribution)
    end

    private

    attr_reader :target_epoch_number

    def epoch_length_distribution
      max_n = 1700
      ranges = [[0, 300]] + (300..max_n).step(100).map { |n| [n, n + 100] }
      ranges.each_with_index.map { |range, index|
        if index.zero?
          epoch_count = ::EpochStatistic.where("epoch_length > 0 and epoch_length <= ?", range[1]).count
        elsif index == max_n + 1
          epoch_count = ::EpochStatistic.where("epoch_length > ?", range[1]).count
        else
          epoch_count = ::EpochStatistic.where("epoch_length > ? and epoch_length <= ?", range[0], range[1]).count
        end

        [range[1], epoch_count]
      }.compact
    end

    def epoch_time_distribution
      max_n = 119
      ranges = [[0, 180]] + (180..(180 + max_n)).map { |n| [n, n + 1] }
      ranges.each_with_index.map { |range, index|
        milliseconds_start = range[0] * 60 * 1000
        milliseconds_end = range[1] * 60 * 1000
        if index.zero?
          epoch_count = ::EpochStatistic.where("epoch_time > 0 and epoch_time <= ?", milliseconds_end).count
        elsif index == max_n + 1
          epoch_count = ::EpochStatistic.where("epoch_time > ?", milliseconds_start).count
        else
          epoch_count = ::EpochStatistic.where("epoch_time > ? and epoch_time <= ?", milliseconds_start, milliseconds_end).count
        end

        [range[1], epoch_count]
      }.compact
    end
  end
end
