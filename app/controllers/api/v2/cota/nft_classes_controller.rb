module Api
  module V2
    class Cota::NFTClassesController < BaseController

      def index
      end

      # GET /token_transfers/1
      def show
        class_id = params[:id]

        res = CotaAggregator.instance.get_define_info(class_id)
        render json: res
      end
    end
  end
end
