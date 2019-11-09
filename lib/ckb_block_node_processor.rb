require_relative "../config/environment"

node_data_processor = CkbSync::NodeDataProcessor.new

loop do
  node_data_processor.call
end