module Api
  module V1
    class MonetaryDataController < ApplicationController
      before_action :validate_query_params, only: :show

      def show
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
