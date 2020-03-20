module Api
  module V1
    class AddressUdtTransactionsController < ApplicationController
      before_action :validate_query_params
      before_action :validate_pagination_params, :pagination_params

      def show
        address = Address.find_address!(params[:id])
        raise Api::V1::Exceptions::AddressNotFoundError if address.is_a?(NullAddress)
        raise Api::V1::Exceptions::TypeHashInvalidError if params[:type_hash].blank?

        udt = Udt.find_by(type_hash: params[:type_hash], published: true)
        raise Api::V1::Exceptions::UdtNotFoundError if udt.blank?

        presented_address = AddressPresenter.new(address)
        ckb_dao_transactions = presented_address.ckb_udt_transactions(params[:type_hash]).recent.distinct.page(@page).per(@page_size)
        options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: ckb_dao_transactions, page: @page, page_size: @page_size).call

        render json: CkbTransactionSerializer.new(ckb_dao_transactions, options.merge({ params: { previews: true } }))
      end

      private

      def validate_query_params
        validator = Validations::AddressUdtTransaction.new(params)

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
