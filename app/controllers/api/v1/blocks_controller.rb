module Api
  module V1
    class BlocksController < ApplicationController
      before_action :validate_query_params, only: :show
      before_action :validate_pagination_params, :pagination_params, only: :index

      def index
        if from_home_page?
          blocks = Block.recent.select(:id, :miner_hash, :number, :timestamp, :reward, :ckb_transactions_count, :live_cell_changes, :updated_at).limit(ENV["HOMEPAGE_BLOCK_RECORDS_COUNT"].to_i)
          json =
            Rails.cache.realize(blocks.cache_key, version: blocks.cache_version, race_condition_ttl: 3.seconds) do
              BlockListSerializer.new(blocks).serialized_json
            end
        else
          blocks = Block.recent.select(:id, :miner_hash, :number, :timestamp, :reward, :ckb_transactions_count, :live_cell_changes, :updated_at)
          asc_or_desc = params[:asc_or_desc] || 'desc'
          order_by = params[:order_by] || 'number'
          blocks = blocks.order(number: asc_or_desc) if params[:order_by] == 'number'
          blocks = blocks.order(reward: asc_or_desc) if params[:order_by] == 'reward'
          blocks = blocks.order(timestamp: asc_or_desc) if params[:order_by] == 'timestamp'
          blocks = blocks.order(ckb_transactions_count: asc_or_desc) if params[:order_by] == 'ckb_transactions_count'
            .page(@page).per(@page_size).fast_page
          json =
            Rails.cache.realize(blocks.cache_key, version: blocks.cache_version, race_condition_ttl: 3.seconds) do
              records_counter = RecordCounters::Blocks.new
              options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: blocks, page: @page, page_size: @page_size, records_counter: records_counter).call
              BlockListSerializer.new(blocks, options).serialized_json
            end
        end

        render json: json
      end

      def show
        json_block = Block.find_block!(params[:id])

        render json: json_block
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
