module Api
  module V1
    class ContractTransactionsController < ApplicationController
      before_action :validate_pagination_params, :pagination_params

      def show
        raise Api::V1::Exceptions::ContractNotFoundError if params[:id] != DaoContract::CONTRACT_NAME

        dao_contract = DaoContract.default_contract

        if stale?(dao_contract)
          expires_in 10.seconds, public: true, must_revalidate: true, stale_while_revalidate: 5.seconds

          ckb_transactions = dao_contract.ckb_transactions.includes(:cell_inputs, :cell_outputs).tx_committed.select(
            :id, :tx_hash, :block_id, :block_number, :block_timestamp, :is_cellbase, :updated_at, :created_at
          ).order("ckb_transactions.block_timestamp desc nulls last, ckb_transactions.id desc")

          if params[:tx_hash].present?
            ckb_transactions = ckb_transactions.where(tx_hash: params[:tx_hash])
          end

          if params[:address_hash].present?
            address = Address.find_address!(params[:address_hash])
            raise Api::V1::Exceptions::AddressNotFoundError if address.is_a?(NullAddress)

            ckb_transactions = ckb_transactions.joins(:account_books).
              where(account_books: { address_id: address.id })
          end

          ckb_transactions = ckb_transactions.page(@page).per(@page_size).fast_page
          options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: ckb_transactions,
                                                             page: @page, page_size: @page_size).call
          json = CkbTransactionsSerializer.new(ckb_transactions,
                                               options.merge(params: { previews: true })).serialized_json

          render json: json
        end
      end

      private

      def pagination_params
        @page = params[:page] || 1
        @page_size = params[:page_size] || CkbTransaction.default_per_page
      end
    end
  end
end
