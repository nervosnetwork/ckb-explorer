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

        ckb_udt_transactions = address.ckb_udt_transactions(udt.id)
          .includes(:cell_inputs => [:previous_cell_output], :cell_outputs => [], :bitcoin_annotation => [])
          .select(select_fields)
          .recent.page(@page).per(@page_size).fast_page
        json =
          Rails.cache.realize(ckb_udt_transactions.cache_key, version: ckb_udt_transactions.cache_version, expires_in: 1.hours) do
            options = FastJsonapi::PaginationMetaGenerator.new(request:, records: ckb_udt_transactions, page: @page, page_size: @page_size).call
            CkbTransactionsSerializer.new(ckb_udt_transactions, options.merge(params: { previews: true })).serialized_json
          end

        render json:
      end

      private

      def select_fields
        %i[ckb_transactions.id ckb_transactions.tx_hash ckb_transactions.tx_index ckb_transactions.block_id ckb_transactions.block_number ckb_transactions.block_timestamp
        ckb_transactions.is_cellbase ckb_transactions.updated_at ckb_transactions.created_at ckb_transactions.tags]
      end

      def validate_query_params
        validator = Validations::AddressUdtTransaction.new(params)

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
