require_relative "../config/environment"

loop do
  CkbSync::NodeDataProcessor.new.call
end