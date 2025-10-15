module Api
  module V1
    class CkbTransactionsController < ApplicationController
      before_action :validate_query_params, only: %i[show]
      before_action :find_transaction, only: %i[show]
      before_action :validate_pagination_params, :pagination_params, only: %i[index]

      def index
        if from_home_page?
          ckb_transactions = CkbTransaction.tx_committed.recent.normal.select(
            :id, :tx_hash, :block_number, :block_timestamp, :live_cell_changes, :capacity_involved, :updated_at, :created_at, :tags
          ).limit((Settings.homepage_transactions_records_count || 15).to_i)
          json =
            Rails.cache.realize(ckb_transactions.cache_key,
                                version: ckb_transactions.cache_version, race_condition_ttl: 3.seconds, expires_in: 2.minutes) do
              CkbTransactionListSerializer.new(ckb_transactions).serialized_json
            end
          render json:
        else
          ckb_transactions = CkbTransaction.tx_committed.normal.select(
            :id, :tx_hash, :block_number, :block_timestamp, :live_cell_changes, :capacity_involved, :updated_at, :created_at, :tags
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
          total_count = TableRecordCount.find_by(table_name: "ckb_transactions")&.count
          json =
            Rails.cache.realize(ckb_transactions.cache_key,
                                version: ckb_transactions.cache_version, race_condition_ttl: 3.seconds, expires_in: 10.minutes) do
              options = FastJsonapi::PaginationMetaGenerator.new(
                request:,
                records: ckb_transactions,
                page: @page,
                page_size: @page_size,
                total_count:,
              ).call
              CkbTransactionListSerializer.new(ckb_transactions,
                                               options).serialized_json
            end
          render json:
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
            @tx_ids =
              AccountBook.tx_committed.where(
                address_id: @address.id,
              ).order(
                "ckb_transaction_id desc",
              ).select(
                "ckb_transaction_id",
              ).page(@page).per(@page_size).fast_page
            total_count = @tx_ids.total_count
            CkbTransaction.where(id: @tx_ids.map(&:ckb_transaction_id)).order(id: :desc)
          else
            total_count = TableRecordCount.find_by(table_name: "ckb_transactions")&.count
            CkbTransaction.recent.normal.page(@page).per(@page_size).fast_page
          end

        includes = { bitcoin_annotation: [], 
              cell_outputs: [:address, :deployed_contract, :type_script, :bitcoin_vout, :lock_script], 
              cell_inputs: [:block, previous_cell_output: [:address, :deployed_contract, :type_script, :bitcoin_vout, :lock_script]]}

        ckb_transactions = ckb_transactions.includes(includes).select(:id, :tx_hash, :block_id, :tags,
                                                   :block_number, :block_timestamp, :is_cellbase, :updated_at, :created_at)
        json =
          Rails.cache.realize(ckb_transactions.cache_key,
                              version: ckb_transactions.cache_version, race_condition_ttl: 1.minute, expires_in: 10.minutes) do
            options = FastJsonapi::PaginationMetaGenerator.new(
              request:,
              records: ckb_transactions,
              page: @page,
              page_size: @page_size,
              total_count: total_count,
            ).call
            CkbTransactionsSerializer.new(ckb_transactions,
                                          options.merge(params: {
                                                          previews: true, address_id: @address.id
                                                        })).serialized_json
          end
        render json:
      end

      def show
        expires_in 10.seconds, public: true, must_revalidate: true

        render json: CkbTransactionSerializer.new(@ckb_transaction, {
                                                    params: { display_cells: params.fetch(:display_cells, true) },
                                                  })
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

          render json: errors, status:
        end
      end

      def find_transaction

        includes = { bitcoin_annotation: [], 
                  witnesses: [],
                  block: [:epoch_statistic],
                  cell_dependencies: [:cell_output, :contract],
                  cell_outputs: [:address, :deployed_contract, :type_script, :bitcoin_vout, :lock_script], 
                  cell_inputs: [:block, previous_cell_output: [:address, :deployed_contract, :type_script, :bitcoin_vout, :lock_script]]}

        @ckb_transaction = CkbTransaction.includes(includes).where(tx_hash: params[:id]).first
        raise Api::V1::Exceptions::CkbTransactionNotFoundError if @ckb_transaction.blank?
      end
    end
  end
end
