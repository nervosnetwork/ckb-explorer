module Api
  module V1
    class AddressTransactionsController < ApplicationController
      before_action :validate_query_params
      before_action :validate_pagination_params, :pagination_params
      before_action :set_address_transactions, only: [:show, :download_csv]

      def show
        expires_in 10.seconds, public: true, must_revalidate: true, stale_while_revalidate: 5.seconds

        order_by, asc_or_desc = account_books_ordering
        tx_ids = AccountBook.joins(:ckb_transaction).
          where(account_books: { address_id: @address.id },
                ckb_transactions: { tx_status: "committed" }).
          order(order_by => asc_or_desc).
          page(@page).per(@page_size).fast_page

        total_count = AccountBook.where(address_id: @address.id).count
        total_count = tx_ids.total_count if total_count < 1_000

        ckb_transaction_ids = tx_ids.map(&:ckb_transaction_id)
        ckb_transactions = CkbTransaction.where(id: ckb_transaction_ids).
          select(:id, :tx_hash, :block_id, :block_number, :block_timestamp,
                 :is_cellbase, :updated_at, :capacity_involved, :created_at).
          order(order_by => asc_or_desc)

        options = FastJsonapi::PaginationMetaGenerator.new(
          request: request,
          records: ckb_transactions,
          page: @page,
          page_size: @page_size,
          total_count: total_count
        ).call
        ckb_transaction_serializer = CkbTransactionsSerializer.new(
          ckb_transactions,
          options.merge(params: { previews: true, address: @address })
        )

        json =
          if QueryKeyUtils.valid_address?(params[:id])
            if @address.address_hash == @address.query_address
              ckb_transaction_serializer.serialized_json
            else
              ckb_transaction_serializer.serialized_json.gsub(@address.address_hash, @address.query_address)
            end
          else
            ckb_transaction_serializer.serialized_json
          end

        render json: json
      end

      def download_csv
        args = params.permit(:id, :start_date, :end_date, :start_number, :end_number, address_transaction: {}).
          merge(address_id: @address.id)
        file = CsvExportable::ExportAddressTransactionsJob.perform_now(args.to_h)

        send_data file, type: "text/csv; charset=utf-8; header=present",
                        disposition: "attachment;filename=ckb_transactions.csv"
      end

      private

      def validate_query_params
        validator = Validations::Address.new(params)

        if validator.invalid?
          errors = validator.error_object[:errors]
          status = validator.error_object[:status]

          render json: errors, status: status
        end
      end

      def pagination_params
        @page = params[:page] || 1
        @page_size = params[:page_size] || CkbTransaction.default_per_page
      end

      def set_address_transactions
        @address = Address.find_address!(params[:id])
        raise Api::V1::Exceptions::AddressNotFoundError if @address.is_a?(NullAddress)
      end

      def account_books_ordering
        sort, order = params.fetch(:sort, "ckb_transaction_id.desc").split(".", 2)
        sort =
          case sort
          when "time" then "ckb_transactions.block_timestamp"
          else "ckb_transactions.id"
          end

        if order.nil? || !order.match?(/^(asc|desc)$/i)
          order = "asc"
        end

        [sort, order]
      end
    end
  end
end
