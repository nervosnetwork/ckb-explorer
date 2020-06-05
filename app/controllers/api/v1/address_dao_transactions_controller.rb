module Api
  module V1
    class AddressDaoTransactionsController < ApplicationController
      before_action :validate_query_params
      before_action :validate_pagination_params, :pagination_params

      def show
        address = Address.find_address!(params[:id])
        raise Api::V1::Exceptions::AddressNotFoundError if address.is_a?(NullAddress)

        ckb_dao_transactions = address.ckb_dao_transactions.recent.page(@page).per(@page_size)
        options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: ckb_dao_transactions, page: @page, page_size: @page_size).call

        render json: CkbTransactionSerializer.new(ckb_dao_transactions, options.merge({ params: { previews: true } }))
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
    end
  end
end
