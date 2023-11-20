module Api
  module V2
    class PendingTransactionsController < BaseController
      before_action :set_page_and_page_size

      def index
        expires_in 10.seconds, public: true, must_revalidate: true, stale_while_revalidate: 5.seconds

        tx_ids = CkbTransaction.tx_pending.ids
        unique_tx_ids = CellInput.where(ckb_transaction_id: tx_ids).
          where.not(previous_cell_output_id: nil, from_cell_base: false).
          pluck(:ckb_transaction_id).uniq
        pending_transactions = CkbTransaction.where(id: unique_tx_ids).
          order(transactions_ordering).page(@page).per(@page_size)

        json = {
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
            total: pending_transactions.total_count,
            page_size: @page_size.to_i
          }
        }

        render json: json
      end

      def count
        render json: {
          data: CkbTransaction.tx_pending.count
        }
      end

      private

      def set_page_and_page_size
        @page = params[:page] || 1
        @page_size = params[:page_size] || CkbTransaction.default_per_page
      end

      def transactions_ordering
        sort, order = params.fetch(:sort, "id.desc").split(".", 2)
        sort =
          case sort
          when "time" then "created_at"
          when "fee" then "transaction_fee"
          when "capacity" then "capacity_involved"
          else "id"
          end

        if order.nil? || !order.match?(/^(asc|desc)$/i)
          order = "asc"
        end

        "#{sort} #{order} NULLS LAST"
      end
    end
  end
end
