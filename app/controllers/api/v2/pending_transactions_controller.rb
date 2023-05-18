module Api::V2
  class PendingTransactionsController < BaseController
    before_action :set_page_and_page_size
    def index
      pending_transactions = CkbTransaction.tx_pending.order("id desc").page(@page).per(@page_size).fast_page
      head :not_found and return if pending_transactions.blank?

      render json: {
        data: pending_transactions.map do |tx|
          {
            transaction_hash: tx.tx_hash,
            capacity_involved: tx.capacity_involved,
            transaction_fee: tx.transaction_fee,
            created_at: tx.created_at
          }
        end,
        meta: {
          total: CkbTransaction.tx_pending.count,
          page_size: @page_size.to_i
        }
      }
    end

    def count
      render json: {
        data: CkbTransaction.tx_pending.count
      }
    end

    def set_page_and_page_size
      @page = params[:page] || 1
      @page_size = params[:page_size] || 10
    end
  end
end
