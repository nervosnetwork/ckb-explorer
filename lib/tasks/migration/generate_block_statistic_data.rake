namespace :migration do
  task generate_block_statistic_data: :environment do
    max_block_number = Block.maximum(:number)
    start_block_number = [BlockStatistic.maximum(:block_number).to_i + 100, 100].max
    range = (start_block_number..max_block_number).step(100)
    progress_bar = ProgressBar.create({
      total: range.count,
      format: "%e %B %p%% %c/%C"
    })
    statistic_info = StatisticInfo.new

    Block.where(number: range.to_a).each do |block|
      hash_rate = statistic_info.hash_rate(block.number)
      total_cells = CellOutput.where("block_timestamp <= ?", block.timestamp)
      ckb_transaction_ids = CkbTransaction.where("block_number <= ?", block.number).ids
      dead_cells_count = total_cells.where(consumed_by_id: ckb_transaction_ids).count
      live_cells_count = total_cells.count - dead_cells_count

      BlockStatistic.create(block_number: block.number, epoch_number: block.epoch, difficulty: block.difficulty, hash_rate: hash_rate, live_cells_count: live_cells_count, dead_cells_count: live_cells_count)
      progress_bar.increment
    end

    puts "done"
  end
end
