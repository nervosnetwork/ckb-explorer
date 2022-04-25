require_relative "../config/environment"

Rails.logger = Logger.new(STDERR)
Rails.logger.level = Logger::DEBUG
ActiveRecord::Base.logger = Rails.logger

lock = Redis::Lock.new('CkbSync', :expiration => 300, :timeout => 30)

at_exit do 
  puts 'exiting & clearing'
  lock.clear
end
puts 'start'
loop do
  lock.lock do
    start = Time.now.to_f
    block = CkbSync::NewNodeDataProcessor.new.call
    tip_block_number = CkbSync::Api.instance.get_tip_block_number
    remain = tip_block_number - block.number
    duration = Time.now.to_f - start
    sleep(1-duration) if remain <= 0 && duration < 1 # only sleep when catched up with network
  end
end


