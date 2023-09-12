namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake 'migration:async_missing_transactions[2023-5-1, 2023-5-31]'"
  task :async_missing_transactions, [:star_date, :end_date] => :environment do |_, args|
    start_at = DateTime.parse(args[:star_date]).beginning_of_day
    end_at = DateTime.parse(args[:end_date]).end_of_day
    count = 0

    blocks = Block.where(created_at: start_at..end_at)
    blocks.find_each do |local_block|
      ApplicationRecord.transaction do
        txs_count1 = local_block.ckb_transactions_count
        txs_count2 = local_block.ckb_transactions.count
        next if txs_count1 == txs_count2

        puts "async missing block number: #{local_block.number}, rpc transactions count: #{txs_count1}, db transactions count: #{txs_count2}"

        node_block = CkbSync::Api.instance.get_block_by_number(local_block.number)
        CkbSync::NewNodeDataProcessor.new.process_block(node_block, refresh_balance: false)
        UpdateAddressInfoWorker.new.perform(local_block.number)
        count += 1
      end
    rescue StandardError => e
      puts "async missing block number: #{local_block.number} failed, error：#{e}"
    end

    puts "done, the number of blocks: #{count}"
  end
end
