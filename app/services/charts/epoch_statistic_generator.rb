module Charts
  class EpochStatisticGenerator
    def initialize(epoch_number)
      @epoch_number = epoch_number
    end

    def call
      return if Block.where(epoch: epoch_number + 1).blank?

      blocks_count = Block.where(epoch: epoch_number).count
      uncles_count = Block.where(epoch: epoch_number).sum(:uncles_count)
      uncle_rate = uncles_count / blocks_count.to_d
      difficulty = Block.where(epoch: epoch_number).first.difficulty

      epoch_statistic = ::EpochStatistic.find_or_create_by(epoch_number: epoch_number)
      epoch_statistic.update(difficulty: difficulty, uncle_rate: uncle_rate)
    end

    private
    attr_reader :epoch_number
  end
end
