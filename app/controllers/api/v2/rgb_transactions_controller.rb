module Api
  module V2
    class RgbTransactionsController < BaseController
      def index
        @ckb_transactions = RgbTransactions::Index.run!(transaction_params)
      end

      private

      def transaction_params
        params.permit(:sort, :leap_direction)
      end
    end
  end
end
