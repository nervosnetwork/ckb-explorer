module Api
  module V1
    class DistributionDataController < ApplicationController
      before_action :validate_query_params, only: :show

      def show
        if params[:id] == 'average_block_time'
          render json: {data: {id: Time.current.to_i, type: "distribution_data", attributes: DailyStatistic.full_average_block_time}}
        else
          distribution_data = DistributionData.new
          render json: DistributionDataSerializer.new(distribution_data, params: { indicator: params[:id] })
        end
      end

      private

      def validate_query_params
        validator = Validations::DistributionData.new(params)

        if validator.invalid?
          errors = validator.error_object[:errors]
          status = validator.error_object[:status]

          render json: errors, status: status
        end
      end
    end
  end
end
