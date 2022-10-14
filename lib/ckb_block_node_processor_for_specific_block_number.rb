require_relative "../config/environment"
require "new_relic/agent"
NewRelic::Agent.manual_start(sync_startup: true)

Rails.logger = Logger.new(STDERR)
Rails.logger.level = ENV.fetch("LOG_LEVEL") { "info" }
ActiveRecord::Base.logger = Rails.logger

# usage: ruby lib/ckb_block_node_processor_for_specific_block_number.rb 8274473
block_number = ARGV[0].to_i
Rails.logger.info "== processing specific block: #{block_number}"
CkbSync::NewNodeDataProcessor.new.process_specific_block_by_number block_number
Rails.logger.info "== exiting & clearing"
