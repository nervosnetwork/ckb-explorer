module Api
  module V2
    module Monitors
      class DailyStatisticsController < BaseController

        def index
          last_daily_statistic_created_at = Time.at DailyStatistic.order('created_at_unixtimestamp desc').first.created_at_unixtimestamp
          last_daily_statistic_date = last_daily_statistic_created_at.strftime("%Y-%m-%d")
          yesterday_date = Time.now.yesterday.strftime("%Y-%m-%d")
          if yesterday_date == last_daily_statistic_date
            status = 'ok'
          else
            status = 'error'
          end

          render json: {
            status: status
          }
        end
      end

    end
  end
end
