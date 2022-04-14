require_relative "../config/environment"

lock = Redis::Lock.new('CkbSync', :expiration => 300, :timeout => 30)

at_exit do 
  lock.clear
end

loop do
  lock.lock do
    CkbSync::NewNodeDataProcessor.new.call
  end
end


