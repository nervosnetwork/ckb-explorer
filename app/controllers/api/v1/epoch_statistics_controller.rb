module Api
  module V1
    class EpochStatisticsController < ApplicationController
      before_action :validate_query_params

      def show
        expires_in 30.minutes, public: true, stale_while_revalidate: 10.minutes, stale_if_error: 10.minutes
        if params[:limit]
          scope = EpochStatistic.order(epoch_number: :desc)
          scope = scope.limit(params[:limit])
          epoch_statistics = scope.to_a.reverse
        else
          epoch_statistics = EpochStatistic.order(epoch_number: :asc)
        end
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
