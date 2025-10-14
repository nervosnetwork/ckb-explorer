module Api
  module V1
    class ContractTransactionsController < ApplicationController
      before_action :validate_pagination_params, :pagination_params

      def show
        raise Api::V1::Exceptions::ContractNotFoundError if params[:id] != DaoContract::CONTRACT_NAME

        dao_contract = DaoContract.default_contract

        if stale?(dao_contract)
          expires_in 10.seconds, public: true, must_revalidate: true, stale_while_revalidate: 5.seconds

          ckb_transactions = dao_contract.ckb_transactions.includes(:cell_inputs, :cell_outputs).tx_committed.order("ckb_transactions.block_timestamp desc nulls last, ckb_transactions.id desc")

          if params[:tx_hash].present?
            ckb_transactions = ckb_transactions.where(tx_hash: params[:tx_hash])
          end

          if params[:address_hash].present?
            address = Address.find_address!(params[:address_hash])
            raise Api::V1::Exceptions::AddressNotFoundError if address.is_a?(NullAddress)

            ckb_transactions = ckb_transactions.joins(:account_books).
              where(account_books: { address_id: address.id })
          end

          includes = { :cell_inputs => {:previous_cell_output => {:type_script => [], :bitcoin_vout => [], :lock_script => [] }, :block => []}, :cell_outputs => {}, :bitcoin_annotation => [], :account_books => {} }

          ckb_transactions = ckb_transactions
                    .includes(includes)
                    .select(select_fields)
                    .page(@page).per(@page_size).fast_page
          options = FastJsonapi::PaginationMetaGenerator.new(request:, records: ckb_transactions,
                                                             page: @page, page_size: @page_size).call
          json = CkbTransactionsSerializer.new(ckb_transactions,
                                               options.merge(params: { previews: true })).serialized_json

          render json:
        end
      end

      def select_fields
        %i[ckb_transactions.id ckb_transactions.tx_hash ckb_transactions.block_id ckb_transactions.block_number ckb_transactions.block_timestamp
        ckb_transactions.is_cellbase ckb_transactions.updated_at ckb_transactions.created_at ckb_transactions.tags]
      end

      def download_csv
        args = params.permit(:start_date, :end_date, :start_number, :end_number)
        file = CsvExportable::ExportContractTransactionsJob.perform_now(args.to_h)

        send_data file, type: "text/csv; charset=utf-8; header=present",
                        disposition: "attachment;filename=contract_transactions.csv"
      end

      private

      def pagination_params
        @page = params[:page] || 1
        @page_size = params[:page_size] || CkbTransaction.default_per_page
      end
    end
  end
end
