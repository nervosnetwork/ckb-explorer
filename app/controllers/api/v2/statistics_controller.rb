module Api::V2
  class StatisticsController < BaseController
    def transaction_fees
      expires_in 15.seconds, public: true
      stats_info = StatisticInfo.default

      render json: {
        transaction_fee_rates: stats_info.transaction_fee_rates,
        pending_transaction_fee_rates: stats_info.pending_transaction_fee_rates,
        last_n_days_transaction_fee_rates: stats_info.last_n_days_transaction_fee_rates
      }
    end
  end
end
