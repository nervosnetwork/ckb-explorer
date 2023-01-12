module Api::V2
  class PendingTransactionsController < BaseController
    before_action :set_page_and_page_size
    def index
      pending_transactions = PoolTransactionEntry.order('id desc').page(@page).per(@page_size)
      head :not_found and return if pending_transactions.blank?

      render json: {
        data: pending_transactions.map { |tx|
          {
            id: tx.id,
            tx_hash: tx.tx_hash,
            capacity_of_inputs: (tx.display_inputs.inject(0) { |sum, x| sum + x['capacity'] } rescue 0),
            transaction_fee: tx.transaction_fee,
            created_at: tx.created_at,
          }
        },
        meta: {
          total: PoolTransactionEntry.count,
          page_size: @page_size.to_i
        }
      }
    end

    def set_page_and_page_size
      @page = params[:page] || 1
      @page_size = params[:page_size] || 10
    end
  end
end
