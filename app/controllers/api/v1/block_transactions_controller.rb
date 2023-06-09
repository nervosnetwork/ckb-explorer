module Api
  module V1
    class BlockTransactionsController < ApplicationController
      before_action :validate_query_params
      before_action :validate_pagination_params, :pagination_params
      include Pagy::Backend
      def show
        block = Block.find_by!(block_hash: params[:id])
        temp_transactions = block.ckb_transactions
          .select(:id, :tx_hash, :block_id, :block_number, :block_timestamp, :is_cellbase, :updated_at)
          .where(block_timestamp: block.timestamp)
        temp_transactions = temp_transactions.where(tx_hash: params[:tx_hash]) if params[:tx_hash].present?
        temp_transactions = temp_transactions.order(id: :desc)

        @pagy, ckb_transactions = pagy(
          temp_transactions,
          items: params[:page_size] || 10,
          overflow: :empty_page
        )

        json =
          Rails.cache.realize(ckb_transactions.cache_key, version: ckb_transactions.cache_version) do
            records_counter = RecordCounters::BlockTransactions.new(block)
            options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: ckb_transactions, page: @pagy.page, page_size: @pagy.items, records_counter: records_counter).call
            CkbTransactionsSerializer.new(ckb_transactions, options.merge(params: { previews: true })).serialized_json
          end

        render json: json
      rescue ActiveRecord::RecordNotFound
        raise Api::V1::Exceptions::BlockTransactionsNotFoundError
      end

      private

      def validate_query_params
        validator = Validations::BlockTransaction.new(params)

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
