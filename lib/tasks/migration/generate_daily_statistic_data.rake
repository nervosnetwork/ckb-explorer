namespace :migration do
  task generate_daily_statistic_data: :environment do
    genesis_block_timestamp = Block.find_by(number: 0).timestamp
    genesis_block_time = DateTime.strptime(genesis_block_timestamp.to_s, "%Q")
    date_range = (genesis_block_time..((DateTime.now - 1.days).beginning_of_day))
    progress_bar = ProgressBar.create({ total: date_range.count, format: "%e %B %p%% %c/%C" })

    date_range.each do |datetime|
      Charts::DailyStatistic.new.perform(datetime.in_time_zone("Beijing").to_datetime)
      progress_bar.increment
    end

    puts "done"
  end
end
