module Api
  module V1
    class StatisticInfoChartsController < ApplicationController
      def index
        statistic_info_chart = StatisticInfoChart.new
        render json: StatisticInfoChartSerializer.new(statistic_info_chart)
      end
    end
  end
end