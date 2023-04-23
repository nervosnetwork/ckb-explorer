module Api
  module V1
    class AddressDaoTransactionsController < ApplicationController
      before_action :validate_query_params
      before_action :validate_pagination_params, :pagination_params

      def show
        address = Address.find_address!(params[:id])
        raise Api::V1::Exceptions::AddressNotFoundError if address.is_a?(NullAddress)

        ckb_dao_transactions = address.ckb_dao_transactions.select(:id, :tx_hash, :block_id, :block_number, :block_timestamp, :is_cellbase, :updated_at).recent.page(@page).per(@page_size).fast_page
        json =
          Rails.cache.realize(ckb_dao_transactions.cache_key, version: ckb_dao_transactions.cache_version) do
            records_counter = RecordCounters::AddressDaoTransactions.new(address)
            options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: ckb_dao_transactions, page: @page, page_size: @page_size, records_counter: records_counter).call
            CkbTransactionsSerializer.new(ckb_dao_transactions, options.merge(params: { previews: true })).serialized_json
          end

        render json: json
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
