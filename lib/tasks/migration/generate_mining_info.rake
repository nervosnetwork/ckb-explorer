namespace :migration do
  task generate_mining_info: :environment do
    max_block_number = Block.maximum(:number)
    range = (0..max_block_number)
    progress_bar = ProgressBar.create({
      total: range.count,
      format: "%e %B %p%% %c/%C"
    })

    address_mining_infos = {}
    values = Block.where(number: range.to_a).order(number: :desc).map do |block|
      miner_address = block.miner_address
      if block.number <= max_block_number - 11
        status = "mined"
        if address_mining_infos.key?(miner_address.id)
          mining_info = address_mining_infos[miner_address.id]
          mined_blocks_count = mining_info[:mined_blocks_count] + 1
          address_mining_infos[miner_address.id] = { mined_blocks_count: mined_blocks_count }
        else
          address_mining_infos[miner_address.id] = { mined_blocks_count: 1 }
        end
      else
        status = "mined"
        if address_mining_infos.key?(miner_address.id)
          mining_info = address_mining_infos[miner_address.id]
          mined_blocks_count = mining_info[:mined_blocks_count] + 1
          address_mining_infos[miner_address.id] = { mined_blocks_count: mined_blocks_count }
        else
          address_mining_infos[miner_address.id] = { mined_blocks_count: 1 }
        end
      end

      progress_bar.increment
      [miner_address.id, block.id, block.number, status]
    end

    columns = [:address_id, :block_id, :block_number, :status ]
    MiningInfo.import columns, values, validate: false, batch_size: 10000

    address_mining_info_columns = [:id, :mined_blocks_count]
    address_mining_info_values = address_mining_infos.map do |key, value|
      [key, value[:mined_blocks_count]]
    end

    Address.import address_mining_info_columns, address_mining_info_values, batch_size: 3000, on_duplicate_key_update: [:mined_blocks_count]

    puts "done"
  end
end
