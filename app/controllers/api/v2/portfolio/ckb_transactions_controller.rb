module Api
  module V2
    module Portfolio
      class CkbTransactionsController < BaseController
        before_action :validate_jwt!
        before_action :pagination_params

        def index
          expires_in 15.minutes, public: true, stale_while_revalidate: 5.minutes, stale_if_error: 5.minutes

          account_books = sort_account_books(filter_account_books).page(@page).per(@page_size).fast_page
          ckb_transactions = CkbTransaction.where(id: account_books.map(&:ckb_transaction_id)).
            select(:id, :tx_hash, :block_id, :block_number, :block_timestamp,
                   :is_cellbase, :updated_at, :capacity_involved).
            order(id: :desc)
          options = FastJsonapi::PaginationMetaGenerator.new(
            request: request,
            records: ckb_transactions,
            page: @page,
            page_size: @page_size,
            records_counter: account_books
          ).call
          ckb_transaction_serializer = CkbTransactionsSerializer.new(
            ckb_transactions,
            options.merge(params: {
              previews: true,
              address: current_user.addresses
            })
          )
          json = ckb_transaction_serializer.serialized_json

          render json: json
        end

        def download_csv
          args = download_params.merge(address_ids: current_user.address_ids)
          file = CsvExportable::ExportPortfolioTransactionsJob.perform_now(args.to_h)

          send_data file, type: "text/csv; charset=utf-8; header=present",
                          disposition: "attachment;filename=portfolio_ckb_transactions.csv"
        end

        private

        def pagination_params
          @page = params[:page] || 1
          @page_size = params[:page_size] || CkbTransaction.default_per_page
        end

        def filter_account_books
          address_ids =
            if params[:address_hash].present?
              address = Address.find_address!(params[:address_hash])
              [address.id]
            else
              current_user.address_ids
            end
          scope = AccountBook.joins(:ckb_transaction).where(
            account_books: { address_id: address_ids },
            ckb_transactions: { tx_status: "committed" }
          )

          if params[:tx_hash].present?
            scope = scope.where(ckb_transactions: { tx_hash: params[:tx_hash] })
          end

          scope
        end

        def sort_account_books(records)
          sort, order = params.fetch(:sort, "ckb_transaction_id.desc").split(".", 2)
          sort = "ckb_transactions.block_timestamp" if sort == "time"

          if order.nil? || !order.match?(/^(asc|desc)$/i)
            order = "asc"
          end

          records.order("#{sort} #{order}")
        end

        def download_params
          params.permit(:start_date, :end_date, :start_number, :end_number)
        end
      end
    end
  end
end
