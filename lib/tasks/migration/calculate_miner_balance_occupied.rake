require "ruby-progressbar"

namespace :migration do
  task calculate_miner_balance_occupied: :environment do
    miner_addresses = Address.where("mined_blocks_count > 0")

    progress_bar = ProgressBar.create({
      total: miner_addresses.count,
      format: "%e %B %p%% %c/%C"
    })
    miner_addresses.each do |address|
      address.update(balance_occupied: address.cal_balance_occupied)
      progress_bar.increment
    end

    puts "done"
  end
end
