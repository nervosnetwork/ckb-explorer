namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:resync_blocks"
  task resync_blocks: :environment do
    numbers = CSV.read("incorrect_blocks.csv").flatten.compact.uniq.map { |n| n.to_i }
    numbers.sort.each do |number|
      sync_block(number, 0)
    end; nil
    puts "done"
  end

  def sync_block(number, retry_count)
    node_block = CkbSync::Api.instance.get_block_by_number(number)
    CkbSync::NewNodeDataProcessor.new.process_block(node_block, refresh_balance: false)
    UpdateAddressInfoWorker.perform_async(number)
  rescue StandardError => _e
    retry_count += 1
    if retry_count > 2
      puts number
    else
      sleep(3)
      sync_block(number, retry_count)
    end
  end
end
