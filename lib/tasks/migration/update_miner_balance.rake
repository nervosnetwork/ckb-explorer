namespace :migration do
  task update_miner_balance: :environment do
    progress_bar = ProgressBar.create({
      total: Address.count,
      format: "%e %B %p%% %c/%C"
    })

    Address.find_each do |addr|
      addr.update(balance: addr.cell_outputs.live.sum(:capacity), ckb_transactions_count: addr.custom_ckb_transactions.count,
        live_cells_count: addr.cell_outputs.live.count)
      progress_bar.increment
    end

    puts "done"
  end
end
