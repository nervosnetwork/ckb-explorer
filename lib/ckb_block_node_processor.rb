require_relative "../config/environment"

lock = Redis::Lock.new('CkbSync', :expiration => 300, :timeout => 30)

loop do
  lock.lock do
    CkbSync::NewNodeDataProcessor.new.call
  end
end
