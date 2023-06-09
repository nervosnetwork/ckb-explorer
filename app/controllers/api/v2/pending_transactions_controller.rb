module Api::V2
  class PendingTransactionsController < BaseController
    before_action :set_page_and_page_size
    def index
      pending_transactions = CkbTransaction.tx_pending

      params[:sort] ||= "id.desc"
      order_by, asc_or_desc = params[:sort].split(".", 2)
      order_by =
        case order_by
             when "time"
               "created_at"
             when "fee"
               "transaction_fee"
             # current we don't support this in DB
             # when 'capacity' then 'capacity_involved'
             else order_by
        end

      head :not_found and return unless order_by.in? %w[id created_at transaction_fee]

      pending_transactions = pending_transactions.order(order_by => asc_or_desc).
        page(@page).per(@page_size).fast_page

      render json: {
        data: pending_transactions.map do |tx|
          {
            transaction_hash: tx.tx_hash,
            capacity_involved: tx.capacity_involved,
            transaction_fee: tx.transaction_fee,
            created_at: tx.created_at,
            create_timestamp: (tx.created_at.to_f * 1000).to_i
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
