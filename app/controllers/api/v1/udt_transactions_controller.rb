module Api
  module V1
    class UdtTransactionsController < ApplicationController
      before_action :validate_pagination_params

      def show
        expires_in 10.seconds, public: true, must_revalidate: true, stale_while_revalidate: 5.seconds

        json = Udts::CkbTransactions.run!(udt_params.merge({ request:, type_hash: params[:id] }))

        render json:
      end

      private

      def udt_params
        params.permit(:tx_hash, :address_hash, :page, :page_size)
      end
    end
  end
end
