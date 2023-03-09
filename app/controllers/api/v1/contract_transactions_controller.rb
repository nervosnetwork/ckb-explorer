module Api
  module V1
    class ContractTransactionsController < ApplicationController
      before_action :validate_pagination_params, :pagination_params

      def show
        raise Api::V1::Exceptions::ContractNotFoundError if params[:id] != DaoContract::CONTRACT_NAME

        dao_contract = DaoContract.default_contract
        ckb_transactions = dao_contract.ckb_transactions.tx_committed.select(:id, :tx_hash, :block_id, :block_number, :block_timestamp, :is_cellbase, :updated_at).recent.page(@page).per(@page_size)
        json =
          Rails.cache.realize(ckb_transactions.cache_key, version: ckb_transactions.cache_version) do
            records_counter = RecordCounters::DaoTransactions.new(dao_contract)
            options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: ckb_transactions, page: @page, page_size: @page_size, records_counter: records_counter).call
            CkbTransactionsSerializer.new(ckb_transactions, options.merge(params: { previews: true })).serialized_json
          end

        render json: json
      end

      private

      def pagination_params
        @page = params[:page] || 1
        @page_size = params[:page_size] || CkbTransaction.default_per_page
      end
    end
  end
end
