module Api
  module V1
    class DailyStatisticsController < ApplicationController
      def show
        daily_statistics = DailyStatistic.limit(365)
        render json: DailyStatisticSerializer.new(daily_statistics, { params: { indicator: params[:id] } })
      end
    end
  end
end
