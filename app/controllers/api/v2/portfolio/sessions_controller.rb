module Api
  module V2
    module Portfolio
      class SessionsController < BaseController
        def create
          json = Users::SignIn.run!(sign_in_params)

          render json:
        end

        private

        def sign_in_params
          params.permit(:address, :message, :signature, :pub_key)
        end
      end
    end
  end
end
