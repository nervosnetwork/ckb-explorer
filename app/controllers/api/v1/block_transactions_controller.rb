module Api
  module V1
    class BlockTransactionsController < ApplicationController
      before_action :validate_query_params, :validate_pagination_params, :pagination_params

      def show
        block = Block.find_by!(block_hash: params[:id])
        ckb_transactions = block.ckb_transactions.select(select_fields).order(tx_index: :asc)
          # select(select_fields + ["COUNT(cell_inputs.id) AS cell_inputs_count", "COUNT(cell_outputs.id) AS cell_outputs_count"])

        if params[:tx_hash].present?
          ckb_transactions = ckb_transactions.where(tx_hash: params[:tx_hash])
        end

        if params[:address_hash].present?
          address = Address.find_address!(params[:address_hash])
          ckb_transactions = ckb_transactions.joins(:account_books).
            where(account_books: { address_id: address.id })
        end

        includes = { :cell_inputs => {:previous_cell_output => {:type_script => [], :bitcoin_vout => [], :lock_script => [] }, :block => []}, :cell_outputs => {}, :bitcoin_annotation => [], :account_books => {} }

        if stale?(ckb_transactions)
          expires_in 10.seconds, public: true, must_revalidate: true, stale_while_revalidate: 5.seconds
          ckb_transactions = ckb_transactions
              .includes(includes)
              .page(@page).per(@page_size).fast_page
              
          options = FastJsonapi::PaginationMetaGenerator.new(
            request:,
            records: ckb_transactions,
            page: @page,
            page_size: @page_size,
          ).call
          json = CkbTransactionsSerializer.new(ckb_transactions,
                                               options.merge(params: { previews: true })).serialized_json

          render json:
        end
      rescue ActiveRecord::RecordNotFound
        raise Api::V1::Exceptions::BlockTransactionsNotFoundError
      end

      private

      def select_fields
        %i[ckb_transactions.id ckb_transactions.tx_hash ckb_transactions.tx_index ckb_transactions.block_id ckb_transactions.block_number ckb_transactions.block_timestamp
          ckb_transactions.is_cellbase ckb_transactions.updated_at ckb_transactions.created_at ckb_transactions.tags]
      end

      def validate_query_params
        validator = Validations::BlockTransaction.new(params)

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
