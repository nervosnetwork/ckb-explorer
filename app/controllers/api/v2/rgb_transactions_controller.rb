module Api
  module V2
    class RgbTransactionsController < BaseController
      def index
        @bitcoin_annotations = RgbTransactions::Index.run!(transaction_params)
      end

      private

      def transaction_params
        params.permit(:sort, :leap_direction, :page, :page_size)
      end
    end
  end
end
