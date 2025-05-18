class SsriIndexer
  include Singleton

  GET_METHODS = "0x58f02409de9de7b1"
  UDT_NAME    = "0xc78a67cec2fcc54f"
  UDT_SYMBOL  = "0x35fa711c8c918aad"
  UDT_DECIMAL = "0x2f87f08056af234d"
  UDT_ICON    = "0xa306f89e40893737"

  def initialize
    @endpoint = ENV.fetch("SSRI_URL")
    @uri = URI.parse(@endpoint)
    @http = Net::HTTP.new(@uri.host, @uri.port)
  end

  def fetch_methods(outpoint_tx_hash, outpoint_index)
    rpc_call("run_script_level_code", [
               outpoint_tx_hash, outpoint_index, [GET_METHODS, "0x0000000000000000", "0x0000000000000000"]
             ])
  end

  def fetch_udt_name(outpoint_tx_hash, outpoint_index, script)
    fetch_udt_field(outpoint_tx_hash, outpoint_index, script, UDT_NAME)
  end

  def fetch_udt_symbol(outpoint_tx_hash, outpoint_index, script)
    fetch_udt_field(outpoint_tx_hash, outpoint_index, script, UDT_SYMBOL)
  end

  def fetch_udt_decimal(outpoint_tx_hash, outpoint_index, script)
    fetch_udt_field(outpoint_tx_hash, outpoint_index, script, UDT_DECIMAL)
  end

  def fetch_udt_icon(outpoint_tx_hash, outpoint_index, script)
    fetch_udt_field(outpoint_tx_hash, outpoint_index, script, UDT_ICON)
  end

  def fetch_all_udt_fields(tx_hash, index, script)
    calls = [
      {
        jsonrpc: "2.0",
        method: "run_script_level_script",
        params: [tx_hash, index, [UDT_NAME], script],
        id: 1,
      },
      {
        jsonrpc: "2.0",
        method: "run_script_level_script",
        params: [tx_hash, index, [UDT_SYMBOL], script],
        id: 2,
      },
      {
        jsonrpc: "2.0",
        method: "run_script_level_script",
        params: [tx_hash, index, [UDT_DECIMAL], script],
        id: 3,
      },
      {
        jsonrpc: "2.0",
        method: "run_script_level_script",
        params: [tx_hash, index, [UDT_ICON], script],
        id: 4,
      },
    ]

    result = batch_rpc_call(calls)

    {
      name: parse_utf8(result[1]),
      symbol: parse_utf8(result[2]),
      decimal: result[3].to_i(16),
      icon: parse_utf8(result[4]),
    }
  end

  private

  def parse_utf8(hex)
    [hex.delete_prefix("0x")].pack("H*").force_encoding("UTF-8").strip
  end

  def fetch_udt_field(outpoint_tx_hash, outpoint_index, script, field)
    rpc_call("run_script_level_script", [outpoint_tx_hash, outpoint_index, [field], script])
  end

  def rpc_call(method, params, id = 0)
    request = Net::HTTP::Post.new(@uri.request_uri, {
                                    "Content-Type": "application/json",
                                  })

    request.body = {
      id: id,
      method: method,
      params: params,
      jsonrpc: "2.0",
    }.to_json

    response = @http.request(request)

    unless response.is_a?(Net::HTTPOK)
      raise "HTTP Error: #{response.code} #{response.message} - #{response.body}"
    end

    body = JSON.parse(response.body)

    if body["error"]
      raise "RPC Error: #{body['error']['message']} (code #{body['error']['code']})"
    end

    body.dig("result", "content")
  end

  def batch_rpc_call(calls)
    request = Net::HTTP::Post.new(@uri.request_uri, {
                                    "Content-Type": "application/json",
                                  })

    request.body = calls.to_json

    response = @http.request(request)

    unless response.is_a?(Net::HTTPOK)
      raise "HTTP Error: #{response.code} #{response.message} - #{response.body}"
    end

    results = JSON.parse(response.body)

    # Convert array of results into hash by id
    results.each_with_object({}) do |res, acc|
      if res["error"]
        raise "RPC Error (id #{res['id']}): #{res['error']['message']}"
      end

      acc[res["id"]] = res.dig("result", "content")
    end
  end
end
