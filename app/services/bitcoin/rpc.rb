module Bitcoin
  class Rpc
    include Singleton

    METHOD_NAMES = %w(getchaintips getrawtransaction getblock getblockhash getblockheader getblockchaininfo).freeze
    SIGNET_WHITELISTED_METHODS = %w(getrawtransaction).freeze

    def initialize
      @id = 0
      @endpoint = ENV["BITCOIN_NODE_URL"]
      @signet_endpoint = ENV["BITCOIN_SIGNET_NODE_URL"]
      @signet_user = ENV["BITCOIN_SIGNET_USER"]
      @signet_pass = ENV["BITCOIN_SIGNET_PASS"]
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

      if mainnet_mode?
        make_request(@endpoint, payload)
      else
        make_signet_request(payload, method) || make_request(@endpoint, payload)
      end
    end

    def mainnet_mode?
      CkbSync::Api.instance.mode == CKB::MODE::MAINNET
    end

    def make_request(endpoint, payload)
      response = HTTP.timeout(60).post(endpoint, json: payload)
      parse_response(response)
    end

    def make_signet_request(payload, method)
      return unless SIGNET_WHITELISTED_METHODS.include?(method)

      begin
        response = HTTP.basic_auth(user: @signet_user, pass: @signet_pass).timeout(60).post(@signet_endpoint, json: payload)
        parse_response(response)
      rescue StandardError => e
        Rails.logger.error("Error making signet request: #{e.message}")
        nil # Return nil if the request fails, allowing fallback to the main testnet endpoint
      end
    end

    def parse_response(response)
      data = JSON.parse(response.to_s)
      raise ArgumentError, data["error"]["message"] if data["error"].present?

      data
    end
  end
end
