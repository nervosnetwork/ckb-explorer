module Api
  module V1
    class UdtTransactionsController < ApplicationController
      before_action :validate_query_params
      before_action :validate_pagination_params, :pagination_params

      def show
        udt = Udt.find_by!(type_hash: params[:id], published: true)
        ckb_transactions = udt.ckb_transactions.select(:id, :tx_hash, :block_id, :block_number, :block_timestamp, :is_cellbase, :updated_at).recent.page(@page).per(@page_size)
        records_counter = RecordCounters::UdtTransactions.new(udt)
        options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: ckb_transactions, page: @page, page_size: @page_size, records_counter: records_counter).call
        json = CkbTransactionsSerializer.new(ckb_transactions, options.merge(params: { previews: true })).serialized_json

        render json: json
      rescue ActiveRecord::RecordNotFound
        raise Api::V1::Exceptions::UdtNotFoundError
      end

      private

      def validate_query_params
        validator = Validations::Udt.new(params)

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
