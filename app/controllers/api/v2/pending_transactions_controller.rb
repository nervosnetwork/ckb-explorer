module Api::V2
  class PendingTransactionsController < BaseController
    before_action :set_page_and_page_size
    def index
      pending_transactions = PoolTransactionEntry.order('id desc').page(@page).per(@page_size)
      head :not_found and return if pending_transactions.blank?

      render json: {
        data: pending_transactions,
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
