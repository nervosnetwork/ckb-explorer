require_relative "../config/environment"

loop do
  CkbSync::NewNodeDataProcessor.new.call
end
