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

        ckb_dao_transactions = address.ckb_udt_transactions(udt.id).select(:id, :tx_hash, :block_id, :block_number, :block_timestamp, :is_cellbase, :updated_at).recent.page(@page).per(@page_size)
        records_counter = RecordCounters::AddressUdtTransactions.new(address, udt.id)
        options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: ckb_dao_transactions, page: @page, page_size: @page_size, records_counter: records_counter).call
        json = CkbTransactionsSerializer.new(ckb_dao_transactions, options.merge(params: { previews: true })).serialized_json

        render json: json
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
