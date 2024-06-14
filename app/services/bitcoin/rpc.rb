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

    def batch_get_raw_transactions(txids)
      payload_generator = Proc.new { |txid, index| { jsonrpc: "1.0", id: index + 1, method: "getrawtransaction", params: [txid, 2] } }
      payload = txids.map.with_index(&payload_generator)

      if mainnet_mode?
        make_request(@endpoint, payload)
      else
        signet_response = make_signet_request(payload, "getrawtransaction")
        return make_request(@endpoint, payload) if signet_response.blank?

        consolidate_responses(signet_response, txids, payload_generator)
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

      return data if data.is_a?(Array)

      if data.is_a?(Hash)
        raise ArgumentError, data["error"]["message"] if data["error"].present?
      else
        raise ArgumentError, "Unexpected response format: #{data.class}"
      end

      data
    end

    def consolidate_responses(signet_response, txids, payload_generator)
      consolidated_response = []
      fetched_txids = []

      signet_response.each do |response|
        if response["result"].present?
          fetched_txids << response["result"]["txid"]
          consolidated_response << response
        end
      end

      unfetched_txids = txids - fetched_txids

      if unfetched_txids.present?
        unfetched_payload = unfetched_txids.map.with_index(&payload_generator)
        consolidated_response.concat(make_request(@endpoint, unfetched_payload))
      end

      consolidated_response
    end
  end
end
