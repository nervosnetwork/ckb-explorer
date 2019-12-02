namespace :migration do
  task generate_epoch_statistic_data: :environment do
    max_epoch_number = Block.maximum(:epoch)
    progress_bar = ProgressBar.create({
      total: max_epoch_number + 1,
      format: "%e %B %p%% %c/%C"
    })

    (0..max_epoch_number).each do |epoch_number|
      blocks_count = Block.where(epoch: epoch_number).count
      uncles_count = Block.where(epoch: epoch_number).sum(:uncles_count)
      uncle_rate = uncles_count / blocks_count.to_d
      difficulty = Block.where(epoch: epoch_number).first.difficulty

      EpochStatistic.create(epoch_number: epoch_number, difficulty: difficulty, uncle_rate: uncle_rate)
      progress_bar.increment
    end

    puts "done"
  end
end
