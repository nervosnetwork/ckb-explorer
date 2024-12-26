module Api
  module V2
    class RgbppAssetsStatisticsController < BaseController
      def index
        expires_in 15.minutes, public: true, stale_while_revalidate: 5.minutes, stale_if_error: 5.minutes

        statistics = RgbppAssetsStatistic.all.order(created_at_unixtimestamp: :asc)
        statistics = statistics.where(network: params[:network]) if params[:network].present?
        statistics = statistics.where(indicator: params[:indicators].split(",")) if params[:indicators].present?

        render json: {
          data: statistics.map do |statistic|
            {
              indicator: statistic.indicator,
              value: statistic.value.to_s,
              network: statistic.network,
              created_at_unixtimestamp: statistic.created_at_unixtimestamp.to_s,
            }
          end,
        }
      end
    end
  end
end
