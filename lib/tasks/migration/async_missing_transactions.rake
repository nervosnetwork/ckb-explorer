class AsyncMissingTransactions
  include Rake::DSL

  def initialize
    namespace :migration do
      desc "Usage: RAILS_ENV=production bundle exec rake migration:generate_referring_cells['2023-5-1', '2023-5-31']"
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

            puts "async missing block number: #{local_block.number} transactions count: #{txs_count1}"

            node_block = CkbSync::Api.instance.get_block_by_number(local_block.number)
            CkbSync::NewNodeDataProcessor.new.process_block(node_block)

            process_duplicate_blocks(local_block.number)
            count += 1
          end
        rescue StandardError => e
          puts "async missing block number: #{local_block.number} failed, error：#{e}"
        end

        puts "done, the number of blocks: #{count}"
      end
    end
  end

  private

  def process_duplicate_blocks(block_number)
    blocks = Block.where(number: block_number).order(id: :asc)
    return if blocks.count == 1

    puts "block number: #{block_number} has two records: #{blocks.map(&:id)}"
    old_block = blocks.first
    puts "delete block #{old_block.id}"
    old_block.mining_infos.first.destroy
    old_block.destroy

    current_block = Block.find_by_number(block_number)
    CkbUtils.update_block_reward!(current_block)
    CkbUtils.calculate_received_tx_fee!(current_block)

    current_block.contained_addresses.each do |address|
      address.cal_balance!
      address.save!
    end

    UpdateAddressInfoWorker.new.perform(block_number)
  end
end

AsyncMissingTransactions.new
