module Api::V2
  class StatisticsController < BaseController
    before_action :set_page_and_page_size

    def transaction_fees
      expires_in 15.seconds, public: true
      transaction_fee_rates =
        CkbTransaction.
          where("bytes > 0 and transaction_fee > 0").order("id desc").limit(10000).pluck(:id, :created_at, :transaction_fee, :bytes, :confirmation_time)

      # select from database
      pending_transaction_fee_rates = PoolTransactionEntry.pool_transaction_pending.
        where("transaction_fee > 0").
        order("id desc").page(@pending_page).per(@pending_page_size).fast_page

      # This is a patch for those pending tx which has no `bytes`
      pending_transaction_fee_rates = pending_transaction_fee_rates.map { |tx|
        tx_bytes = 0
        if tx.bytes.blank? || tx.bytes == 0
          Rails.logger.info "== checking tx bytes: #{tx.tx_hash}, #{tx.id}"
          begin
            tx_bytes = CkbSync::Api.instance.get_transaction(tx.tx_hash).transaction.serialized_size_in_block
          rescue Exception => e
            Rails.logger.error "== tx not found"
            tx_bytes = 0
          end
          tx.update bytes: tx_bytes
        end

        tx
      }.select { |e| e.bytes > 0 }

      render json: {
        transaction_fee_rates: transaction_fee_rates.map do |tx|
          {
            id: tx[0],
            timestamp: tx[1].to_i,
            fee_rate: (tx[2].to_f / tx[3]),
            confirmation_time: tx[4]
          }
        end,
        pending_transaction_fee_rates: pending_transaction_fee_rates.map do |tx|
          {
            id: tx.id,
            fee_rate: (tx.transaction_fee.to_f / tx.bytes)
          }
        end,
        last_n_days_transaction_fee_rates: Rails.cache.fetch(
          "last_n_days_transaction_fee_rates", expires_in: 3.hours, race_condition_ttl: 1.minute
        ) do
                                             CkbTransaction.last_n_days_transaction_fee_rates(@last_n_day)
                                           end
      }
    end

    private

    def set_page_and_page_size
      @last_n_day = (params[:last_n_day] || 6).to_i
      @last_n_day = 20 if @last_n_day > 20
      @pending_tx_page = params[:pending_tx_page] || 1
      @pending_tx_page_size = params[:pending_tx_page_size] || 100
    end
  end
end
