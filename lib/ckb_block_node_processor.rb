require_relative "../config/environment"

Rails.logger = Logger.new(STDERR)
Rails.logger.level = ENV.fetch("LOG_LEVEL") { "info" }
ActiveRecord::Base.logger = Rails.logger

at_exit do
  puts 'exiting & clearing'
end

# process all the not processed blocks
if ARGV == []
  remain = 0
  duration = 0
  loop do
    ApplicationRecord.with_advisory_lock('CkbSyncer') do
      start = Time.now.to_f
      block = CkbSync::NewNodeDataProcessor.new.call
      if block
        tip_block_number = CkbSync::Api.instance.get_tip_block_number
        remain = tip_block_number - block.number
        duration = Time.now.to_f - start
      else
        remain = 0
        duration = 0
      end
    end
    sleep(1-duration) if remain <= 0 && duration < 1 # only sleep when catched up with network
  end

# process a specific block
# usage: ruby lib/ckb_block_node_processor_for_specific_block_number.rb 8274473
else
  block_number = ARGV[0].to_i
  Rails.logger.info "== processing specific block: #{block_number}"
  CkbSync::NewNodeDataProcessor.new.process_specific_block_by_number block_number
  Rails.logger.info "== exiting & clearing"
end



