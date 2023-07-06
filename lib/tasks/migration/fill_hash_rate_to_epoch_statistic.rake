namespace :migration do
  task fill_hash_rate_to_epoch_static: :environment do
    max_epoch_number = Block.maximum(:epoch)
    progress_bar = ProgressBar.create({ total: max_epoch_number + 1, format: "%e %B %p%% %c/%C" })
    columns = [:epoch_number, :hash_rate]
    values =
      (0..max_epoch_number).map do |epoch_number|
        first_block_in_epoch = Block.where(epoch: epoch_number).order(:number).first
        last_block_in_epoch = Block.where(epoch: epoch_number).order(:number).last
        block_time = last_block_in_epoch.timestamp - first_block_in_epoch.timestamp
        epoch_length = Block.where(epoch: epoch_number).count
        hash_rate = BigDecimal(first_block_in_epoch.difficulty * epoch_length) / block_time
        progress_bar.increment
        [epoch_number, hash_rate]
      end
    ::EpochStatistic.import(columns, values, validate: false, on_duplicate_key_update: { conflict_target: [:epoch_number], columns: [:hash_rate] })

    puts "done"
  end
end
