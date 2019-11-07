module Api
  module V1
    class ContractTransactionsController < ApplicationController
      before_action :validate_pagination_params, :pagination_params

      def show
        raise Api::V1::Exceptions::ContractNotFoundError if params[:id] != "dao"
        dao_contract = DaoContract.default_contract
        ckb_transactions = dao_contract.ckb_transactions.distinct.recent.page(@page).per(@page_size)
        options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: ckb_transactions, page: @page, page_size: @page_size).call

        render json: CkbTransactionSerializer.new(ckb_transactions, options.merge({ params: { previews: true } }))
      end

      private

      def pagination_params
        @page = params[:page] || 1
        @page_size = params[:page_size] || CkbTransaction.default_per_page
      end
    end
  end
end

