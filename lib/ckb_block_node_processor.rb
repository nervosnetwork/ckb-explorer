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
    start = Time.now.to_f
    CkbSync::NewNodeDataProcessor.new.call
    duration = Time.now.to_f - start
    sleep(1-duration) if duration < 1
  end
end


