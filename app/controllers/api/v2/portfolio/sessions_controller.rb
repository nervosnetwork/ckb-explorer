module Api
  module V2
    module Portfolio
      class SessionsController < BaseController
        before_action :validate_query_params

        def create
          user = User.find_or_create_by(identifier: params[:address])
          payload = { uuid: user.uuid }

          render json: {
            name: user.name,
            jwt: PortfolioUtils.generate_jwt(payload)
          }
        end

        private

        def validate_query_params
          validator = Validations::PortfolioSignature.new(params)

          if validator.invalid?
            errors = validator.error_object[:errors]
            status = validator.error_object[:status]

            render json: errors, status: status
          end
        end
      end
    end
  end
end
