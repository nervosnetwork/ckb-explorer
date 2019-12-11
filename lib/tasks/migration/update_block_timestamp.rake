namespace :migration do
  task update_block_timestamp: :environment do
    blocks_count = Block.count
    progress_bar = ProgressBar.create({ total: blocks_count, format: "%e %B %p%% %c/%C" })
    Block.order(:timestamp).find_each do |block|
      block.contained_addresses.where(block_timestamp: nil).update_all(block_timestamp: block.timestamp)
      block.cell_outputs.update_all(block_timestamp: block.timestamp)

      progress_bar.increment
    end

    puts "done"
  end
end
