module Api
  module V2
    class BitcoinTransactionsController < BaseController
      def query
        cache_keys = params[:txids]
        res = Rails.cache.read_multi(*cache_keys)

        not_cached = cache_keys - res.keys
        to_cache = {}

        raw_transactions = ->(txids) do
          Bitcoin::Rpc.instance.batch_get_raw_transactions(txids)
        end

        if not_cached.present?
          raw_transactions.call(not_cached).each do |tx|
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
    end
  end
end
