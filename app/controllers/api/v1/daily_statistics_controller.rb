module Api
  module V1
    class DailyStatisticsController < ApplicationController
      before_action :validate_query_params, only: :show

      def show
        daily_statistics = DailyStatistic.limit(365)
        binding.pry
        render json: DailyStatisticSerializer.new(daily_statistics, { params: { indicator: params[:id] } })
      end

      private

      def validate_query_params
        validator = Validations::DailyStatistic.new(params)

        if validator.invalid?
          errors = validator.error_object[:errors]
          status = validator.error_object[:status]

          render json: errors, status: status
        end
      end
    end
  end
end
