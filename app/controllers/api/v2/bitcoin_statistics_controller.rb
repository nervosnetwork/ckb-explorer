module Api
  module V2
    class BitcoinStatisticsController < BaseController
      def index
        expires_in 15.minutes, public: true, stale_while_revalidate: 5.minutes, stale_if_error: 5.minutes

        render json: { data: BitcoinStatistic.all }
      end
    end
  end
end
