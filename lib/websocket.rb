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

class TransactionProcessor
  attr_accessor :ckb_transaction

  def process_outputs
    data["outputs"].each_with_index do |output, i|
      build_output(output, i, data["outputs_data"][i])
    end
  end

  def process_inputs
  end

  def build_output(output, index, data)
    c = CellOutput.find_or_create_by(ckb_transaction_id: ckb_transaction.id)
    c.capacity = output["capacity"]
    c.cell_index = index
    c.address_id = Address
    c.type_script_id = build_type_script(output["type"])
    c.lock_script_id = build_lock_script(output["lock"])
    c.data = data
    c.save
  end

  def build_type_script(raw_script)
  end

  def build_lock_script(raw_script)
  end
end

queue = Queue.new

persister =
  Thread.new do
    Rails.application.executor.wrap do
      data = queue.pop
      tx = data["transaction"]
      entry = PoolTransactionEntry.new
      entry.cell_deps = tx["cell_deps"]
      entry.tx_hash = tx["tx_hash"]
      entry.header_deps = tx["header_deps"]
      entry.inputs = tx["inputs"]
      entry
    end
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
