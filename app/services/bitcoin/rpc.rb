module Bitcoin
  class Rpc
    include Singleton

    METHOD_NAMES = %w(getchaintips getrawtransaction getblock getblockhash getblockheader getblockchaininfo)
    def initialize(endpoint = ENV["BITCOIN_NODE_URL"])
      @endpoint = endpoint
      @id = 0
    end

    METHOD_NAMES.each do |name|
      define_method name do |*params|
        call_rpc(name, params:)
      end
    end

    private

    def call_rpc(method, params: [])
      @id += 1
      payload = { jsonrpc: "1.0", id: @id, method:, params: }
      response = HTTP.timeout(10).post(@endpoint, json: payload)
      data = JSON.parse(response.to_s)
      if (err = data["error"]).present?
        raise ArgumentError, err["message"]
      else
        data["result"]
      end
    end
  end
end
