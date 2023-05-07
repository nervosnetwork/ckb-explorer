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
          blocks = Block.select(:id, :miner_hash, :number, :timestamp, :reward, :ckb_transactions_count, :live_cell_changes, :updated_at)
          params[:sort] ||= "timestamp.desc"
          temp = params[:sort].split('.')
          order_by = temp[0]
          asc_or_desc = temp[1]
          order_by = case order_by
          when 'height' then 'number'
          when 'transactions' then 'ckb_transactions_count'
          else order_by
          end

          head :not_found and return unless order_by.in? %w[number reward timestamp ckb_transactions_count]
          blocks = blocks.order(Arel.sql("#{order_by} #{asc_or_desc}")).page(@page).per(@page_size).fast_page

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
