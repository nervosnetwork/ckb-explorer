module Api
  module V2
    class UdtHourlyStatisticsController < BaseController
      def show
        expires_in 15.minutes, public: true, stale_while_revalidate: 5.minutes, stale_if_error: 5.minutes

        udt = Udt.find_by!(type_hash: params[:id], published: true)
        hourly_statistics =
          if udt.present?
            UdtHourlyStatistic.where(udt:).order(created_at_unixtimestamp: :asc)
          else
            UdtHourlyStatistic.none
          end

        render json: {
          data: hourly_statistics.map do |statistic|
            {
              ckb_transactions_count: statistic.ckb_transactions_count,
              amount: statistic.amount,
              holders_count: statistic.holders_count,
              created_at_unixtimestamp: statistic.created_at_unixtimestamp,
            }
          end,
        }
      end
    end
  end
end
