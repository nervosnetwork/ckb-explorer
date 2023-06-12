require_relative "../config/environment"
require "new_relic/agent"
NewRelic::Agent.manual_start(sync_startup: true)

Rails.logger = Logger.new(STDERR)
Rails.logger.level = ENV.fetch("LOG_LEVEL") { "info" }
ActiveRecord::Base.logger = Rails.logger

check_environments if Rails.env.production?

at_exit do
  puts "exiting & clearing"
end

puts "start"
remain = 0
duration = 0
loop do
  ApplicationRecord.with_advisory_lock("CkbSyncer") do # use advisory lock to prevent two node processor
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
  sleep(1 - duration) if remain <= 0 && duration < 1 # only sleep when catched up with network
end
