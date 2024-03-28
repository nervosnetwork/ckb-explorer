module Api
  module V1
    class AddressLiveCellsController < ApplicationController
      before_action :validate_pagination_params

      def show
        expires_in 1.minute, public: true, must_revalidate: true, stale_while_revalidate: 10.seconds

        json = Addresses::LiveCells.run!(
          { request:,
            key: params[:id], sort: params[:sort],
            page: params[:page], page_size: params[:page_size] },
        )
        render json:
      end
    end
  end
end
