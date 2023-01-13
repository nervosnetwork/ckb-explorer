require_relative "../config/environment"
require "new_relic/agent"
NewRelic::Agent.manual_start(sync_startup: true)

Rails.logger = Logger.new(STDERR)
Rails.logger.level = ENV.fetch("LOG_LEVEL") { "info" }
ActiveRecord::Base.logger = Rails.logger

at_exit do
  puts "exiting & clearing"
end

require "async"
require "async/http"
require "async/websocket"
require "protocol/websocket/json_message"
URL = ENV.fetch("CKB_WS_URL", "http://localhost:28114")
$message_id = 0

def subscribe(connection, topic)
  $message_id += 1
  message = Protocol::WebSocket::JSONMessage.generate({
    "id": $message_id,
    "jsonrpc": "2.0",
    "method": "subscribe",
    "params": [topic]
  })
  message.send(connection)
  connection.flush
end

Async do |_task|
  endpoint = Async::HTTP::Endpoint.parse(URL, alpn_protocols: Async::HTTP::Protocol::HTTP11.names)

  Async::WebSocket::Client.connect(endpoint) do |connection|
    subscribe connection, "new_transaction"

    while message = connection.read
      message = Protocol::WebSocket::JSONMessage.wrap(message)
      res = message.to_h
      if res[:method] == "subscribe"
        data = JSON.parse res[:params][:result]
        p data
      end
    end
  end
end
