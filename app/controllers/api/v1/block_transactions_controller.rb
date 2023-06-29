module Api
  module V1
    class BlockTransactionsController < ApplicationController
      before_action :validate_query_params, :validate_pagination_params, :pagination_params

      def show
        block = Block.find_by!(block_hash: params[:id])
        ckb_transactions = block.ckb_transactions.
          select(:id, :tx_hash, :block_id, :block_number, :block_timestamp, :is_cellbase, :updated_at).
          order(:id)

        if params[:tx_hash].present?
          ckb_transactions = ckb_transactions.where(tx_hash: params[:tx_hash])
        end

        if params[:address_hash].present?
          address = Address.find_address!(params[:address_hash])
          ckb_transactions = ckb_transactions.joins(:account_books).
            where(account_books: { address_id: address.id })
        end

        if stale?(ckb_transactions)
          expires_in 10.seconds, public: true, must_revalidate: true, stale_while_revalidate: 5.seconds
          records_counter = RecordCounters::BlockTransactions.new(ckb_transactions)
          ckb_transactions = ckb_transactions.page(@page).per(@page_size).fast_page
          options = FastJsonapi::PaginationMetaGenerator.new(
            request: request,
            records: ckb_transactions,
            page: @page,
            page_size: @page_size,
            records_counter: records_counter
          ).call
          json = CkbTransactionsSerializer.new(ckb_transactions,
                                               options.merge(params: { previews: true })).serialized_json

          render json: json
        end
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
