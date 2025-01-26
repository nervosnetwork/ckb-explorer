module Api
  module V2
    module Fiber
      class StatisticsController < BaseController
        def index
          expires_in 15.minutes, public: true, stale_while_revalidate: 5.minutes, stale_if_error: 5.minutes
          statistics = FiberStatistic.order(created_at_unixtimestamp: :desc).limit(7)

          render json: {
            data: statistics.map do |statistic|
              statistic.attributes.except("id", "created_at", "updated_at").transform_values(&:to_s)
            end,
          }
        end

        def show
          expires_in 15.minutes, public: true, stale_while_revalidate: 5.minutes, stale_if_error: 5.minutes
          statistics = FiberStatistic.filter_by_indicator(params[:id]).order(created_at_unixtimestamp: :desc).limit(14)

          render json: { data: statistics.map { _1.attributes.except("id").transform_values(&:to_s) } }
        end
      end
    end
  end
end
