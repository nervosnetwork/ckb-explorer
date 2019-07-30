require_relative "../config/environment"

node_data_processor = CkbSync::NodeDataProcessor.new

loop do
  node_data_processor.call
  sleep(ENV["BLOCK_PROCESS_LOOP_INTERVAL"].to_i)
end