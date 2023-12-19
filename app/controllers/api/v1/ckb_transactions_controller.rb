module Api
  module V1
    class CkbTransactionsController < ApplicationController
      before_action :validate_query_params, only: [:show, :display_inputs, :display_outputs]
      before_action :find_transaction, only: [:show, :display_inputs, :display_outputs]
      before_action :validate_pagination_params, :pagination_params, only: [:index, :display_inputs, :display_outputs]

      def index
        if from_home_page?
          ckb_transactions = CkbTransaction.tx_committed.recent.normal.select(
            :id, :tx_hash, :block_number, :block_timestamp, :live_cell_changes, :capacity_involved, :updated_at, :created_at
          ).limit((Settings.homepage_transactions_records_count || 15).to_i)
          json =
            Rails.cache.realize(ckb_transactions.cache_key,
                                version: ckb_transactions.cache_version, race_condition_ttl: 3.seconds) do
              CkbTransactionListSerializer.new(ckb_transactions).serialized_json
            end
          render json: json
        else
          ckb_transactions = CkbTransaction.tx_committed.normal.select(
            :id, :tx_hash, :block_number, :block_timestamp, :live_cell_changes, :capacity_involved, :updated_at, :created_at
          )

          params[:sort] ||= "id.desc"

          order_by, asc_or_desc = params[:sort].split(".", 2)
          order_by =
            case order_by
                     when "height"
                       "block_number"
                     when "capacity"
                       "capacity_involved"
                     else
                       order_by
            end

          head :not_found and return unless order_by.in? %w[
            id block_number block_timestamp transaction_fee
            capacity_involved
          ]

          ckb_transactions = ckb_transactions.order(order_by => asc_or_desc).
            page(@page).per(@page_size).fast_page

          json =
            Rails.cache.realize(ckb_transactions.cache_key,
                                version: ckb_transactions.cache_version, race_condition_ttl: 3.seconds) do
              records_counter = RecordCounters::Transactions.new
              options = FastJsonapi::PaginationMetaGenerator.new(
                request: request,
                records: ckb_transactions,
                page: @page,
                page_size: @page_size,
                records_counter: records_counter
              ).call
              CkbTransactionListSerializer.new(ckb_transactions,
                                               options).serialized_json
            end
          render json: json
        end
      end

      def query
        @page = params[:page] || 1
        @page_size = params[:page_size] || 10

        if params[:address]
          @address = Address.cached_find(params[:address])
        end

        ckb_transactions =
          if @address
            records_counter = @tx_ids =
              AccountBook.where(
                address_id: @address.id
              ).order(
                "ckb_transaction_id" => :desc
              ).select(
                "ckb_transaction_id"
              ).page(@page).per(@page_size).fast_page
            CkbTransaction.where(id: @tx_ids.map(&:ckb_transaction_id)).order(id: :desc)
          else
            records_counter = RecordCounters::Transactions.new
            CkbTransaction.recent.normal.page(@page).per(@page_size).fast_page
          end
        ckb_transactions = ckb_transactions.select(:id, :tx_hash, :block_id,
                                                   :block_number, :block_timestamp, :is_cellbase, :updated_at, :created_at)
        json =
          Rails.cache.realize(ckb_transactions.cache_key,
                              version: ckb_transactions.cache_version, race_condition_ttl: 1.minute) do
            options = FastJsonapi::PaginationMetaGenerator.new(
              request: request,
              records: ckb_transactions,
              page: @page,
              page_size: @page_size,
              records_counter: records_counter
            ).call
            CkbTransactionsSerializer.new(ckb_transactions,
                                          options.merge(params: {
                                            previews: true, address: @address })).serialized_json
          end
        render json: json
      end

      def show
        expires_in 10.seconds, public: true, must_revalidate: true

        render json: CkbTransactionSerializer.new(@ckb_transaction)
      end

      def display_inputs
        expires_in 1.hour, public: true, must_revalidate: true

        if @ckb_transaction.is_cellbase
          cell_inputs = @ckb_transaction.cellbase_display_inputs
          total_count = cell_inputs.count
        else
          cell_inputs = @ckb_transaction.cell_inputs.order(id: :asc).
            page(@page).per(@page_size).fast_page
          total_count = cell_inputs.total_count
          cell_inputs = @ckb_transaction.normal_tx_display_inputs(cell_inputs)
        end

        render json: { data: cell_inputs, meta: { total: total_count, page_size: @page_size.to_i } }
      end

      def display_outputs
        expires_in 1.hour, public: true, must_revalidate: true

        if @ckb_transaction.is_cellbase
          cell_outputs = @ckb_transaction.cellbase_display_outputs
          total_count = cell_outputs.count
        else
          cell_outputs = @ckb_transaction.outputs.order(id: :asc).
            page(@page).per(@page_size).fast_page
          total_count = cell_outputs.total_count
          cell_outputs = @ckb_transaction.normal_tx_display_outputs(cell_outputs)
        end

        render json: { data: cell_outputs, meta: { total: total_count, page_size: @page_size.to_i } }
      end

      private

      def from_home_page?
        params[:page].blank? || params[:page_size].blank?
      end

      def pagination_params
        @page = (params[:page] || 1).to_i
        @page_size = params[:page_size] || CkbTransaction.default_per_page
        if @page > 5000
          render json: { error: "exceed max page" }, status: :not_found
        end
      end

      def validate_query_params
        validator = Validations::CkbTransaction.new(params)

        if validator.invalid?
          errors = validator.error_object[:errors]
          status = validator.error_object[:status]

          render json: errors, status: status
        end
      end

      def find_transaction
        @ckb_transaction = CkbTransaction.where(tx_hash: params[:id]).order(tx_status: :desc).first
        raise Api::V1::Exceptions::CkbTransactionNotFoundError if @ckb_transaction.blank?

        if @ckb_transaction.tx_status.to_s == "rejected" && @ckb_transaction.detailed_message.blank?
          PoolTransactionUpdateRejectReasonWorker.perform_async(@ckb_transaction.tx_hash)
        end
      end
    end
  end
end
