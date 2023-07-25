require "csv"
module Api
  module V1
    class BlocksController < ApplicationController
      before_action :validate_query_params, only: :show
      before_action :validate_pagination_params, :pagination_params, only: :index

      def index
        if from_home_page?
          blocks = Block.recent.select(:id, :miner_hash, :number, :timestamp, :reward, :ckb_transactions_count,
                                       :live_cell_changes, :updated_at).limit(ENV["HOMEPAGE_BLOCK_RECORDS_COUNT"].to_i)
          json =
            Rails.cache.realize(blocks.cache_key, version: blocks.cache_version, race_condition_ttl: 3.seconds) do
              BlockListSerializer.new(blocks).serialized_json
            end
        else
          blocks = Block.select(:id, :miner_hash, :number, :timestamp, :reward, :ckb_transactions_count,
                                :live_cell_changes, :updated_at)
          params[:sort] ||= "number.desc"

          order_by, asc_or_desc = params[:sort].split(".", 2)
          order_by =
            case order_by
                     when "height"
                       "number"
                     when "transactions"
                       "ckb_transactions_count"
                     else
                       order_by
            end

          head :not_found and return unless order_by.in? %w[number reward timestamp ckb_transactions_count]

          blocks = blocks.order(order_by => asc_or_desc).page(@page).per(@page_size)

          json =
            Rails.cache.realize(blocks.cache_key, version: blocks.cache_version, race_condition_ttl: 3.seconds) do
              records_counter = RecordCounters::Blocks.new
              options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: blocks, page: @page,
                                                                 page_size: @page_size, records_counter: records_counter).call
              BlockListSerializer.new(blocks, options).serialized_json
            end
        end

        render json: json
      end

      def show
        json_block = Block.find_block!(params[:id])

        render json: json_block
      end

      def download_csv
        args = params.permit(:start_date, :end_date, :start_number, :end_number, block: {})
        file = CsvExportable::ExportBlockTransactionsJob.perform_now(args)

        send_data file, type: "text/csv; charset=utf-8; header=present",
                        disposition: "attachment;filename=blocks.csv"
      end

      private

      def from_home_page?
        params[:page].blank? || params[:page_size].blank?
      end

      def pagination_params
        @page = params[:page] || 1
        @page_size = params[:page_size] || Block.default_per_page
      end

      def validate_query_params
        validator = Validations::Block.new(params)

        if validator.invalid?
          errors = validator.error_object[:errors]
          status = validator.error_object[:status]

          render json: errors, status: status
        end
      end
    end
  end
end
