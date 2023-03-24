module Api::V2
  class StatisticsController < BaseController
    before_action :set_page_and_page_size

    def transaction_fees

      transaction_fee_rates = Rails.cache.fetch("last_10000_transaction_fees", expires_in: 10.seconds) do
        CkbTransaction.select(:id, :created_at, :transaction_fee, :bytes, :confirmation_time)
          .where('bytes > 0 and transaction_fee > 0').order('id desc').limit(10000)
      end

      # select from database
      pending_transaction_fee_rates = PoolTransactionEntry.pool_transaction_pending
        .where('transaction_fee > 0')
        .order('id desc').page(@pending_page).per(@pending_page_size)

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
      }.select {|e| e.bytes > 0}

      render json: {
        transaction_fee_rates: transaction_fee_rates.map {|tx|
          {
            id: tx.id,
            timestamp: tx.created_at.to_i,
            fee_rate: (tx.transaction_fee.to_f / tx.bytes),
            confirmation_time: tx.confirmation_time
          }
        },
        pending_transaction_fee_rates: pending_transaction_fee_rates.map { |tx|
          {
            id: tx.id,
            fee_rate: (tx.transaction_fee.to_f / tx.bytes),
          }
        },
        last_n_days_transaction_fee_rates: CkbTransaction.last_n_days_transaction_fee_rates(@last_n_day)
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
