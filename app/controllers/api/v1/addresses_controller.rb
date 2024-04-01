module Api
  module V1
    class AddressesController < ApplicationController
      def show
        expires_in 1.minute, public: true, must_revalidate: true, stale_while_revalidate: 10.seconds

        json = Addresses::Info.run!(
          { request:, key: params[:id],
            page: params[:page], page_size: params[:page_size] },
        )
        render json:
      end
    end
  end
end
