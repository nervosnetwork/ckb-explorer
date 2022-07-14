module Api
  module V1
    class EpochStatisticsController < ApplicationController
      before_action :validate_query_params

      def show
        scope = EpochStatistic.order(epoch_number: :desc)
        if params[:limit]
          scope = scope.limit(params[:limit])
        end
        epoch_statistics = scope.to_a.reverse
        render json: EpochStatisticSerializer.new(epoch_statistics, { params: { indicator: params[:id] } })
      end

      private

      def validate_query_params
        validator = Validations::EpochStatistic.new(params)

        if validator.invalid?
          errors = validator.error_object[:errors]
          status = validator.error_object[:status]

          render json: errors, status: status
        end
      end
    end
  end
end
