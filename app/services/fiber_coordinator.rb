class FiberCoordinator
  include Singleton
  METHOD_NAMES = %w(graph_nodes graph_channels list_channels).freeze

  def initialize
    @id = 0
  end

  METHOD_NAMES.each do |name|
    define_method name do |endpoint, *params|
      call_rpc(name, endpoint, params:)
    end
  end

  private

  def call_rpc(method, endpoint, params: [])
    @id += 1
    payload = { jsonrpc: "2.0", id: @id, method:, params: }
    make_request(endpoint, payload)
  end

  def make_request(endpoint, payload)
    response = HTTP.timeout(60).post(endpoint, json: payload)
    parse_response(response)
  end

  def parse_response(response)
    data = JSON.parse(response.to_s)

    return data if data.is_a?(Array)

    if data.is_a?(Hash)
      raise ArgumentError, data["error"]["data"] if data["error"].present?
    else
      raise ArgumentError, "Unexpected response format: #{data.class}"
    end

    data
  end
end
