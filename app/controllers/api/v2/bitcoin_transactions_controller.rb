module Api
  module V2
    class BitcoinTransactionsController < BaseController
      def query
        cache_keys = params[:txids]
        res = Rails.cache.read_multi(*cache_keys)

        not_cached = cache_keys - res.keys
        to_cache = {}

        if not_cached.present?
          get_raw_transactions(not_cached).each do |tx|
            next if tx.dig("error").present?

            txid = tx.dig("result", "txid")
            res[txid] = tx
            to_cache[txid] = tx
          end
        end

        Rails.cache.write_multi(to_cache, expires_in: 10.minutes) unless to_cache.empty?

        render json: res
      rescue StandardError => e
        Rails.logger.error "get raw transactions(#{params[:txids]}) failed: #{e.message}"
        render json: {}, status: :not_found
      end

      private

      def get_raw_transactions(txids)
        payload = txids.map.with_index do |txid, index|
          { jsonrpc: "1.0", id: index + 1, method: "getrawtransaction", params: [txid, 2] }
        end
        response = HTTP.timeout(10).post(ENV["BITCOIN_NODE_URL"], json: payload)
        JSON.parse(response.to_s)
      end
    end
  end
end
