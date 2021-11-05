namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:fill_balance_occupied_to_address"
  task :fill_balance_occupied_to_address, [:skip_addr_ids] => :environment do |_, args|
    puts "time: #{Time.current}"
    progress_bar = ProgressBar.create({
      total: Address.count,
      format: "%e %B %p%% %c/%C"
    })
    skip_addr_ids = args[:skip_addr_ids].split(" ").map(&:to_i).presence || []
    Address.find_each do |addr|
      next if addr.id.in?(skip_addr_ids)

      addr.update(balance_occupied: addr.cal_balance_occupied)
      progress_bar.increment
    end

    puts "done"
    puts "time: #{Time.current}"
  end
end
