namespace :migration do
  task generate_epoch_statistic_data: :environment do
    max_epoch_number = Block.maximum(:epoch)
    progress_bar = ProgressBar.create({
      total: max_epoch_number + 1,
      format: "%e %B %p%% %c/%C"
    })

    (0...max_epoch_number).each do |epoch_number|
      Charts::EpochStatisticGenerator.new(epoch_number).call
      progress_bar.increment
    end

    puts "done"
  end
end
