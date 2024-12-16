module Api
  module V2
    class RgbppHourlyStatisticsController < BaseController
      def index
        expires_in 15.minutes, public: true, stale_while_revalidate: 5.minutes, stale_if_error: 5.minutes

        rgbpp_statistics = RgbppHourlyStatistic.order(created_at_unixtimestamp: :asc)

        render json: {
          data: rgbpp_statistics.map do |statistic|
            {
              xudt_count: statistic.xudt_count.to_s,
              dob_count: statistic.dob_count.to_s,
              created_at_unixtimestamp: statistic.created_at_unixtimestamp.to_s,
            }
          end,
        }
      end
    end
  end
end
