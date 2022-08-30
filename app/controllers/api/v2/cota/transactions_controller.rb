module Api
  module V2
    class Cota::TransactionsController < BaseController

      def index
        res = CotaAggregator.instance.get_history_transactions(
          cota_id: params[:class_id], 
          token_index: params[:token_id],
          page: params[:page]
        )

        render json: {
          data: res,
          pagination: {
            page: params[:page]
          }
        }
      end
    end
  end
end
