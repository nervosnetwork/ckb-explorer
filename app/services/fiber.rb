class Fiber
  include Singleton

  METHOD_NAMES = %w(list_channels).freeze

  def initialize
    @id = 0
    @endpoint = ENV["FIBER_RPC_URL"]
  end

  METHOD_NAMES.each do |name|
    define_method name do |*params|
      call_rpc(name, params:)
    end
  end

  private

  def call_rpc(method, params: [])
    @id += 1
    payload = { jsonrpc: "2.0", id: @id, method:, params: }
    make_request(@endpoint, payload)
  end

  def make_request(endpoint, payload)
    response = HTTP.timeout(60).post(endpoint, json: payload)
    parse_response(response)
  end

  def parse_response(response)
    data = JSON.parse(response.to_s)

    return data if data.is_a?(Array)

    if data.is_a?(Hash)
      raise ArgumentError, data["error"]["message"] if data["error"].present?
    else
      raise ArgumentError, "Unexpected response format: #{data.class}"
    end

    data
  end
end
