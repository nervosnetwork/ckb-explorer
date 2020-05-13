namespace :migration do
  task generate_average_times: :environment do
    BlockTimeStatistic.new.generate_monthly

    puts "done"
  end
end
