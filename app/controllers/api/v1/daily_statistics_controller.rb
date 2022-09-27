module Api
  module V1
    class DailyStatisticsController < ApplicationController
      before_action :validate_query_params, only: :show

      def show
        daily_statistics = DailyStatistic.order(:created_at_unixtimestamp).valid_indicators

        render json: rendered_json(daily_statistics)
      end

      private

      def rendered_json(daily_statistics)
        case params[:id]
        when "avg_hash_rate"
          DailyStatisticSerializer.new(daily_statistics.presence || [], { params: { indicator: params[:id] } })
        when "transactions_count"
          DailyStatisticSerializer.new(daily_statistics.presence || [], { params: { indicator: params[:id] } })
        else
          DailyStatisticSerializer.new(daily_statistics, { params: { indicator: params[:id] } })
        end
      end

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
