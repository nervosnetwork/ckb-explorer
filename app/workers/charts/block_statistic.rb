module Charts
  class BlockStatistic
    include Sidekiq::Worker
    sidekiq_options unique: :until_executed
    sidekiq_options retry: false
    sidekiq_options queue: "critical"

    def perform
      latest_block_statistic = BlockStatistic.order(:id).last
      target_block = Block.find_by(number: latest_block_statistic.block_number + 100)
      return if target_block.blank?

      statistic_info = StatisticInfo.new
      hash_rate = statistic_info.hash_rate(block.number)
      live_cell_count = CellOutput.live.count
      dead_cell_count = CellOutput.dead.count

      BlockStatistic.create(block_number: target_block.number, difficulty: target_block.difficulty, hash_rate: hash_rate, live_cell_count: live_cell_count, dead_cell_count: dead_cell_count)
    end
  end
end
