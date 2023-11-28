module Api
  module V1
    class AddressPendingTransactionsController < ApplicationController
      before_action :validate_query_params
      before_action :validate_pagination_params, :pagination_params
      before_action :find_address

      def show
        expires_in 10.seconds, public: true, must_revalidate: true, stale_while_revalidate: 10.seconds

        ckb_transactions = @address.ckb_transactions.tx_pending
        ckb_transactions_ids = CellInput.where(ckb_transaction_id: ckb_transactions.ids).
          where.not(previous_cell_output_id: nil, from_cell_base: false).
          distinct.pluck(:ckb_transaction_id)
        @ckb_transactions = CkbTransaction.where(id: ckb_transactions_ids).
          order(transactions_ordering).page(@page).per(@page_size)

        render json: serialized_ckb_transactions
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

      def find_address
        @address = Address.find_address!(params[:id])
        raise Api::V1::Exceptions::AddressNotFoundError if @address.is_a?(NullAddress)
      end

      def transactions_ordering
        sort, order = params.fetch(:sort, "id.desc").split(".", 2)
        sort = case sort
               when "time" then "block_timestamp"
               else "id"
               end

        order = order.match?(/^(asc|desc)$/i) ? order : "asc"

        "#{sort} #{order} NULLS LAST"
      end

      def serialized_ckb_transactions
        options = FastJsonapi::PaginationMetaGenerator.new(
          request: request,
          records: @ckb_transactions,
          page: @page,
          page_size: @page_size
        ).call
        ckb_transaction_serializer = CkbTransactionsSerializer.new(
          @ckb_transactions,
          options.merge(params: { previews: true, address: @address })
        )

        if QueryKeyUtils.valid_address?(params[:id])
          if @address.address_hash == @address.query_address
            ckb_transaction_serializer.serialized_json
          else
            ckb_transaction_serializer.serialized_json.gsub(
              @address.address_hash, @address.query_address
            )
          end
        else
          ckb_transaction_serializer.serialized_json
        end
      end
    end
  end
end
