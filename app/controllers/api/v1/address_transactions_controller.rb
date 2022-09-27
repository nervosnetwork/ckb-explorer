module Api
  module V1
    class AddressTransactionsController < ApplicationController
      before_action :validate_query_params
      before_action :validate_pagination_params, :pagination_params

      def show
        @address = Address.find_address!(params[:id])
        raise Api::V1::Exceptions::AddressNotFoundError if @address.is_a?(NullAddress)

        @tx_ids = AccountBook.where(address_id: @address.id).order("ckb_transaction_id" => :desc).select("ckb_transaction_id").page(@page).per(@page_size)
        @ckb_transactions = CkbTransaction.where(id: @tx_ids.map(&:ckb_transaction_id)).select(:id, :tx_hash, :block_id, :block_number, :block_timestamp, :is_cellbase, :updated_at).order(id: :desc)
        @options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: @ckb_transactions, page: @page, page_size: @page_size, records_counter: @tx_ids).call
        json = json_result

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

      def json_result
        ckb_transaction_serializer = CkbTransactionsSerializer.new(@ckb_transactions, @options.merge(params: { previews: true, address: @address }))

        if QueryKeyUtils.valid_address?(params[:id])
          if @address.address_hash == @address.query_address
            ckb_transaction_serializer.serialized_json
          else
            ckb_transaction_serializer.serialized_json.gsub(@address.address_hash, @address.query_address)
          end
        else
          ckb_transaction_serializer.serialized_json
        end
      end
    end
  end
end
