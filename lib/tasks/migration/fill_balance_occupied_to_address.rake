namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:fill_balance_occupied_to_address"
  task fill_balance_occupied_to_address: :environment do
    puts "time: #{Time.current}"
    progress_bar = ProgressBar.create({
      total: Address.count,
      format: "%e %B %p%% %c/%C"
    })

    Address.find_each do |addr|
      addr.update(balance_occupied: addr.cal_balance_occupied)
      progress_bar.increment
    end

    puts "done"
    puts "time: #{Time.current}"
  end
end
