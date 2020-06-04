module Api
  module V1
    class AddressTransactionsController < ApplicationController
      before_action :validate_query_params
      before_action :validate_pagination_params, :pagination_params

      def show
        @address = Address.find_address!(params[:id])
        raise Api::V1::Exceptions::AddressNotFoundError if @address.is_a?(NullAddress)

        @ckb_transactions = @address.custom_ckb_transactions.recent.page(@page).per(@page_size)
        @options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: @ckb_transactions, page: @page, page_size: @page_size).call

        render json: json_result
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

      def json_result
        ckb_transaction_serializer = CkbTransactionSerializer.new(@ckb_transactions, @options.merge({ params: { previews: true, address: @address } }))

        if QueryKeyUtils.valid_address?(params[:id])
          if @address.address_hash == @address.query_address
            ckb_transaction_serializer
          else
            ckb_transaction_serializer.serialized_json.gsub(@address.address_hash, @address.query_address)
          end
        else
          ckb_transaction_serializer
        end
      end
    end
  end
end
