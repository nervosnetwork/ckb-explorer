module Api
  module V2
    class BitcoinTransactionsController < BaseController
      def raw
        expires_in 1.minute, public: true, must_revalidate: true, stale_while_revalidate: 10.seconds

        raw_transaction = rpc.getrawtransaction(params[:id], 2)
        if raw_transaction.dig("error").present?
          head :not_found
        else
          render json: raw_transaction
        end
      rescue StandardError => e
        Rails.logger.error "get raw transaction(#{params[:id]}) faild: #{e.message}"
        head :not_found
      end

      private

      def rpc
        @rpc ||= Bitcoin::Rpc.instance
      end
    end
  end
end
