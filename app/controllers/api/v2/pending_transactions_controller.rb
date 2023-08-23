module Api
  module V2
    class PendingTransactionsController < BaseController
      before_action :set_page_and_page_size

      def index
        pending_transactions = CkbTransaction.tx_pending.includes(:cell_inputs).
          where.not(cell_inputs: { previous_cell_output_id: nil, from_cell_base: false })

        if stale?(pending_transactions)
          expires_in 10.seconds, public: true, must_revalidate: true, stale_while_revalidate: 5.seconds

          total_count = pending_transactions.count
          pending_transactions = sort_transactions(pending_transactions).
            page(@page).per(@page_size).fast_page

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
              total: total_count,
              page_size: @page_size.to_i
            }
          }
          render json: json
        end
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

      def sort_transactions(records)
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

        records.order("#{sort} #{order} NULLS LAST")
      end
    end
  end
end
