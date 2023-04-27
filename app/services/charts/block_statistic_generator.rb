module Charts
  class BlockStatisticGenerator
    def initialize(block_number)
      @block_number = block_number
    end

    def call
      target_block = Block.find_by(number: block_number)
      return if target_block.blank?

      hash_rate = StatisticInfo.hash_rate(block_number)
      live_cells_count = CellOutput.live.count
      dead_cells_count = CellOutput.dead.count
      block_statistic = ::BlockStatistic.find_or_create_by(block_number: block_number)
      block_statistic.update(epoch_number: target_block.epoch,
                             difficulty: target_block.difficulty,
                             hash_rate: hash_rate,
                             live_cells_count: live_cells_count,
                             dead_cells_count: dead_cells_count)
    end

    private

    attr_reader :block_number
  end
end
