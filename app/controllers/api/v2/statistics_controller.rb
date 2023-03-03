module Api::V2
  class StatisticsController < BaseController
    before_action :set_page_and_page_size

    def transaction_fees

      transaction_fee_rates = Rails.cache.fetch("transaction_fees", expires_in: 10.seconds) do
        CkbTransaction.select(:id, :created_at, :transaction_fee, :bytes, :confirmation_time).where('bytes > 0').order('id desc').limit(10000)
      end

      pending_transaction_fee_rates = PoolTransactionEntry.select(:id, :transaction_fee, :bytes).pool_transaction_pending
        .where('bytes > 0')
        .order('id desc').page(@pending_page).per(@pending_page_size)

      dates = (0..@last_n_day).map { |i| i.days.ago.strftime("%Y-%m-%d") }
      last_n_days_transaction_fee_rates = dates.map { |date|
        Block.fetch_transaction_fee_rate_from_cache date
      }

      render json: {
        transaction_fee_rates: transaction_fee_rates.map {|tx|
          {
            id: tx.id,
            timestamp: tx.created_at.to_i,
            fee_rate: (tx.transaction_fee / tx.bytes),
            confirmation_time: tx.confirmation_time
          }
        },
        pending_transaction_fee_rates: pending_transaction_fee_rates.map { |tx|
          {
            id: tx.id,
            fee_rate: (tx.transaction_fee / tx.bytes),
          }
        },
        last_n_days_transaction_fee_rates: last_n_days_transaction_fee_rates.map { |day_fee_rate|
          {
            date: (day_fee_rate[0] rescue '-'),
            fee_rate: (day_fee_rate[1].to_f rescue 0)
          }
        }
      }
    end

    private
    def set_page_and_page_size
      @last_n_day = (params[:last_n_day] || 6 ).to_i
      @last_n_day = 20 if @last_n_day > 20
      @pending_tx_page = params[:pending_tx_page] || 1
      @pending_tx_page_size = params[:pending_tx_page_size] || 100
    end
  end
end
