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

URL = "http://testnet-node-websocket.testnet.layerview.io/"

Async do |_task|
  endpoint = Async::HTTP::Endpoint.parse(URL, alpn_protocols: Async::HTTP::Protocol::HTTP11.names)

  Async::WebSocket::Client.connect(endpoint) do |connection|
    while message = connection.read
      p message
    end
  end
end
