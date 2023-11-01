module Api
  module V1
    class MonetaryDataController < ApplicationController
      before_action :validate_query_params, only: :show

      def show
        expires_in 1.hour, public: true, stale_while_revalidate: 10.minutes, stale_if_error: 1.hour

        monetary_data = MonetaryData.new

        render json: MonetaryDataSerializer.new(monetary_data, params: { indicator: params[:id] })
      end

      def validate_query_params
        validator = Validations::MonetaryData.new(params)

        if validator.invalid?
          errors = validator.error_object[:errors]
          status = validator.error_object[:status]

          render json: errors, status: status
        end
      end
    end
  end
end
