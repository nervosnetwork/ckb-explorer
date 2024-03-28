module Api::V2
  class StatisticsController < BaseController
    def transaction_fees
      expires_in 15.seconds, public: true
      stats_info = StatisticInfo.default

      render json: {
        transaction_fee_rates: stats_info.transaction_fee_rates,
        pending_transaction_fee_rates: stats_info.pending_transaction_fee_rates,
        last_n_days_transaction_fee_rates: stats_info.last_n_days_transaction_fee_rates,
      }
    end

    def contract_resource_distributed
      expires_in 30.minutes, public: true

      json = Contract.filter_nil_hash_type.map do |contract|
        {
          name: contract.name,
          code_hash: contract.code_hash,
          hash_type: contract.hash_type,
          tx_count: contract.ckb_transactions_count,
          ckb_amount: (contract.total_referring_cells_capacity / 10**8).truncate(8),
          address_count: contract.addresses_count,
        }
      end

      render json:
    end
  end
end
