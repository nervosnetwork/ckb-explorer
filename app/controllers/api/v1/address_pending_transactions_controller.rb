module Api
  module V1
    class AddressPendingTransactionsController < ApplicationController
      before_action :validate_pagination_params

      def show
        json = Addresses::PendingTransactions.run!(
          { request:,
            key: params[:id], sort: params[:sort],
            page: params[:page], page_size: params[:page_size] },
        )
        render json:
      end
    end
  end
end
