require 'csv'
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
          blocks = Block.recent.select(:id, :miner_hash, :number, :timestamp, :reward, :ckb_transactions_count, :live_cell_changes, :updated_at).page(@page).per(@page_size).fast_page
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

      def download_csv
        @blocks = Block.select(:id, :miner_hash, :number, :timestamp, :reward, :ckb_transactions_count, :live_cell_changes, :updated_at)
        @blocks = @blocks.where('created_at >= ?', params[:start_date]) if params[:start_date].present?
        @blocks = @blocks.where('created_at <= ?', params[:end_date]) if params[:end_date].present?
        @blocks = @blocks.where('number >= ?', params[:number]) if params[:number].present?
        @blocks = @blocks.where('number <= ?', params[:number]) if params[:number].present?
        @blocks = @blocks.limit(5000)

        file = CSV.generate do |csv|
          csv << ["Blockno", "Transactions", "UnixTimestamp", "Reward(CKB)", "Miner", "date(UTC)"]
          @blocks.each_with_index do |block, index|
            row = [block.number, block.ckb_transactions_count, block.timestamp, block.reward, block.miner_hash, block.updated_at]
            csv << row
          end
        end
        send_data file, :type => 'text/csv; charset=utf-8; header=present', :disposition => "attachment;filename=blocks.csv"
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
