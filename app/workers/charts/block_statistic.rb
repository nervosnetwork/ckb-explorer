module Charts
  class BlockStatistic
    include Sidekiq::Worker
    sidekiq_options unique: :until_executed
    sidekiq_options retry: false
    sidekiq_options queue: "critical"

    def perform
      latest_block_statistic = ::BlockStatistic.order(:id).last
      target_block_number = latest_block_statistic.block_number.to_i + 100
      target_block = Block.find_by(number: target_block_number)
      return if target_block.blank?

      statistic_info = StatisticInfo.new
      hash_rate = statistic_info.hash_rate(target_block_number)
      live_cells_count = CellOutput.live.count
      dead_cells_count = CellOutput.dead.count

      ::BlockStatistic.create(block_number: target_block.number, difficulty: target_block.difficulty, hash_rate: hash_rate, live_cell_count: live_cells_count, dead_cell_count: dead_cells_count)
    end
  end
end
