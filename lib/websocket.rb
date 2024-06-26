require_relative "../config/environment"
require "new_relic/agent"

NewRelic::Agent.manual_start(sync_startup: true)

Rails.logger = Logger.new(STDERR)
Rails.logger.level = ENV.fetch("LOG_LEVEL") { "info" }
ActiveRecord::Base.logger = Rails.logger

at_exit do
  puts "exiting & clearing"
end

check_environments if Rails.env.production?
require "faye/websocket"
require "eventmachine"
URL = ENV.fetch("CKB_WS_URL", "http://localhost:28114")
$message_id = 0
$count = 0

queue = Queue.new

persister =
  Thread.new do
    Rails.application.executor.wrap do
      loop do
        data = queue.pop

        begin
          ImportTransactionJob.new.perform(data["transaction"], {
                                             cycles: data["cycles"].hex,
                                             fee: data["fee"].hex,
                                             size: data["size"].hex,
                                             timestamp: data["timestamp"].hex,
                                           })
        rescue StandardError => e
          Rails.logger.error "Error occurred during ImportTransactionJob data: #{data}, error: #{e.message}"
        end
      end
    end
  end

EM.run do
  ws = Faye::WebSocket::Client.new(URL)

  ws.on :open do |_event|
    p [:open]
    response = ws.send('{ "id": 2, "jsonrpc": "2.0", "method": "subscribe", "params": ["new_transaction"] }')
  end

  ws.on :message do |_event|
    $count += 1
    Rails.logger.info Time.now.to_i
  end

  ws.on :close do |event|
    Rails.logger.info $count
    p [:close, event.code, event.reason]
    ws = nil
  end
end
