namespace :migration do
  task generate_daily_statistic_data: :environment do
    genesis_block_timestamp = Block.find_by(number: 0).timestamp
    genesis_block_time = Time.at(genesis_block_timestamp.to_f / 1000)
    current_time = genesis_block_time.in_time_zone
    ended_at = Time.current.yesterday
    total = ((ended_at - current_time) / 60 / 60 / 24).ceil
    progress_bar = ProgressBar.create({ total: total, format: "%e %B %p%% %c/%C" })

    while current_time <= ended_at
      Charts::DailyStatistic.new.perform(current_time.beginning_of_day)
      current_time = current_time + 1.days
      progress_bar.increment
    end

    puts "done"
  end
end
