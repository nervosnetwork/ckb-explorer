module Api
  module V1
    class DailyStatisticsController < ApplicationController
      before_action :validate_query_params, only: :show

      def show
        daily_statistics = DailyStatistic.order(:id).valid_indicators
        json =
          Rails.cache.realize(daily_statistics.cache_key, version: daily_statistics.cache_version, race_condition_ttl: 3.seconds) do
            DailyStatisticSerializer.new(daily_statistics, { params: { indicator: params[:id] } })
          end
        render json: json
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
