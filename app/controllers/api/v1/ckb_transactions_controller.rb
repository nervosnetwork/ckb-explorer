module Api
  module V1
    class CkbTransactionsController < ApplicationController
      before_action :validate_query_params, only: :show
      before_action :validate_pagination_params, :pagination_params, only: :index

      def index
        if from_home_page?
          ckb_transactions = CkbTransaction.recent.normal.limit(ENV["HOMEPAGE_TRANSACTIONS_RECORDS_COUNT"].to_i).select(:id, :tx_hash, :block_number, :block_timestamp, :live_cell_changes, :capacity_involved, :updated_at)
          json =
            Rails.cache.realize(ckb_transactions.cache_key, version: ckb_transactions.cache_version, race_condition_ttl: 3.seconds) do
              CkbTransactionListSerializer.new(ckb_transactions).serialized_json
            end
          render json: json
        else
          ckb_transactions = CkbTransaction.recent.normal.page(@page).per(@page_size).select(:id, :tx_hash, :block_number, :block_timestamp, :live_cell_changes, :capacity_involved, :updated_at)
          json =
            Rails.cache.realize(ckb_transactions.cache_key, version: ckb_transactions.cache_version, race_condition_ttl: 3.seconds) do
              records_counter = RecordCounters::Transactions.new
              options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: ckb_transactions, page: @page, page_size: @page_size, records_counter: records_counter).call
              CkbTransactionListSerializer.new(ckb_transactions, options).serialized_json
            end
          render json: json
        end
      end

      def query
        @page = params[:page] || 1
        @page_size = params[:page_size]  || 10

        if params[:address]
          @address = Address.cached_find(params[:address])
        end

        ckb_transactions =
          if @address
            records_counter = @tx_ids = AccountBook.where(address_id: @address.id).order("ckb_transaction_id" => :desc).select("ckb_transaction_id").page(@page).per(@page_size)
            CkbTransaction.where(id: @tx_ids.map(&:ckb_transaction_id)).order(id: :desc)
          else
            records_counter = RecordCounters::Transactions.new
            CkbTransaction.recent.normal.page(@page).per(@page_size)
          end
        ckb_transactions = ckb_transactions.select(:id, :tx_hash, :block_id, :block_number, :block_timestamp, :is_cellbase, :updated_at)
        json = Rails.cache.realize(ckb_transactions.cache_key, version: ckb_transactions.cache_version, race_condition_ttl: 3.seconds) do

          options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: ckb_transactions, page: @page, page_size: @page_size, records_counter: records_counter).call
          CkbTransactionsSerializer.new(ckb_transactions, options.merge(params: { previews: true, address: @address })).serialized_json
        end
        render json: json
      end

      def show
        ckb_transaction = CkbTransaction.cached_find(params[:id]) || PoolTransactionEntry.find_by(tx_hash: params[:id])

        raise Api::V1::Exceptions::CkbTransactionNotFoundError if ckb_transaction.blank?

        if ckb_transaction.is_a?(PoolTransactionEntry) && ckb_transaction.tx_status.to_s == "rejected" && ckb_transaction.detailed_message.blank?
          ckb_transaction.update_detailed_message_for_rejected_transaction
        end

        render json: CkbTransactionSerializer.new(ckb_transaction)
      end

      private


      def from_home_page?
        params[:page].blank? || params[:page_size].blank?
      end

      def pagination_params
        @page = params[:page] || 1
        @page_size = params[:page_size] || CkbTransaction.default_per_page
      end

      def validate_query_params
        validator = Validations::CkbTransaction.new(params)

        if validator.invalid?
          errors = validator.error_object[:errors]
          status = validator.error_object[:status]

          render json: errors, status: status
        end
      end
    end
  end
end
