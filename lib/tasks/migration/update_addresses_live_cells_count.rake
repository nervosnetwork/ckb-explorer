namespace :migration do
  task update_addresses_live_cells_count: :environment do
    addresses_count = Address.count
    progress_bar = ProgressBar.create({ total: addresses_count, format: "%e %B %p%% %c/%C" })
    Address.find_each do |address|
      address.update_column(:live_cells_count, address.cell_outputs.live.count)

      progress_bar.increment
    end

    puts "done"
  end
end
