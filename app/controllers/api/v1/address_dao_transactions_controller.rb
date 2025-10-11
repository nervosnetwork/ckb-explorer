module Api
  module V1
    class AddressDaoTransactionsController < ApplicationController
      before_action :validate_query_params
      before_action :validate_pagination_params, :pagination_params

      def show
        address = Address.find_address!(params[:id])
        raise Api::V1::Exceptions::AddressNotFoundError if address.is_a?(NullAddress)

        ckb_dao_transactions = address.ckb_dao_transactions
          .includes(:cell_inputs => [:previous_cell_output], :outputs => [], :bitcoin_annotation => [])
          # .joins("LEFT JOIN cell_inputs ON cell_inputs.ckb_transaction_id = ckb_transactions.id")
          # .joins("LEFT JOIN cell_outputs ON cell_outputs.ckb_transaction_id = ckb_transactions.id")
          # .group(select_fields.join(','))
          # .select(select_fields + ["COUNT(cell_inputs.id) AS cell_inputs_count", "COUNT(cell_outputs.id) AS cell_outputs_count"])
          .select(select_fields)
          .recent.page(@page).per(@page_size)

        json =
          Rails.cache.realize(ckb_dao_transactions.cache_key, version: ckb_dao_transactions.cache_version, expires_in: 1.hours) do
            options = FastJsonapi::PaginationMetaGenerator.new(request:, records: ckb_dao_transactions, page: @page, page_size: @page_size).call
            CkbTransactionsSerializer.new(ckb_dao_transactions, options.merge(params: { previews: true })).serialized_json
          end

        render json:
      end

      private

      def select_fields
        %i[ckb_transactions.id ckb_transactions.tx_hash ckb_transactions.tx_index ckb_transactions.block_id ckb_transactions.block_number ckb_transactions.block_timestamp
        ckb_transactions.is_cellbase ckb_transactions.updated_at ckb_transactions.created_at ckb_transactions.tags]
      end

      def validate_query_params
        validator = Validations::Address.new(params)

        if validator.invalid?
          errors = validator.error_object[:errors]
          status = validator.error_object[:status]

          render json: errors, status:
        end
      end

      def pagination_params
        @page = params[:page] || 1
        @page_size = params[:page_size] || CkbTransaction.default_per_page
      end
    end
  end
end
