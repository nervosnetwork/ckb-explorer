module Api
  module V2
    module Portfolio
      class CkbTransactionsController < BaseController
        before_action :validate_jwt!
        before_action :validate_pagination_params, :pagination_params

        def index
          expires_in 30.minutes, public: true, stale_while_revalidate: 10.minutes, stale_if_error: 10.minutes

          tx_ids = AccountBook.joins(:ckb_transaction).
            where(account_books: { address_id: current_user.address_ids },
                  ckb_transactions: { tx_status: "committed" })

          tx_ids = tx_ids.order(ckb_transaction_id: :desc).page(@page).per(@page_size).fast_page
          @ckb_transactions = CkbTransaction.where(id: @tx_ids.map(&:ckb_transaction_id)).
            select(:id, :tx_hash, :block_id, :block_number, :block_timestamp, :is_cellbase, :updated_at, :capacity_involved).
            order(id: :desc)

          @options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: @ckb_transactions,
                                                              page: @page, page_size: @page_size, records_counter: @tx_ids).call

          ckb_transaction_serializer = CkbTransactionsSerializer.new(@ckb_transactions,
                                                                     @options.merge(params: {
                                                                       previews: true,
                                                                       address: @address }))

          json = ckb_transaction_serializer.serialized_json

          render json: json
        end

        private

        def pagination_params
          @page = params[:page] || 1
          @page_size = params[:page_size] || CkbTransaction.default_per_page
        end
      end
    end
  end
end
