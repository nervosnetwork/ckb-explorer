require_relative "../config/environment"
Rails.logger = Logger.new(STDERR)

lock = Redis::Lock.new('CkbSync', :expiration => 300, :timeout => 30)

at_exit do 
  puts 'exiting & clearing'
  lock.clear
end
puts 'start'
loop do
  lock.lock do
    CkbSync::NewNodeDataProcessor.new.call
  end
end


