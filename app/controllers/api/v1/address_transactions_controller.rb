require 'csv'
module Api
  module V1
    class AddressTransactionsController < ApplicationController
      before_action :validate_query_params
      before_action :validate_pagination_params, :pagination_params
      before_action :set_address_transactions, only: [:show, :download_csv]

      def show
        @tx_ids = AccountBook.where(address_id: @address.id).order("ckb_transaction_id" => :desc).select("ckb_transaction_id").page(@page).per(@page_size)
        @ckb_transactions = CkbTransaction.where(id: @tx_ids.map(&:ckb_transaction_id)).select(:id, :tx_hash, :block_id, :block_number, :block_timestamp, :is_cellbase, :updated_at).order(id: :desc)
        json =
          Rails.cache.realize("#{@ckb_transactions.cache_key}/#{@address.query_address}", version: @ckb_transactions.cache_version) do
            @options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: @ckb_transactions, page: @page, page_size: @page_size, records_counter: @tx_ids).call
            json_result
          end

        render json: json
      end

      def download_csv
        @tx_ids = AccountBook.where(address_id: @address.id).order("ckb_transaction_id" => :desc).select("ckb_transaction_id").limit(5000)
        @ckb_transactions = CkbTransaction.where(id: @tx_ids.map(&:ckb_transaction_id)).select(:id, :tx_hash, :block_id, :block_number, :block_timestamp, :is_cellbase, :updated_at).order(id: :desc)
        @ckb_transactions = @ckb_transactions.where('updated_at >= ?', params[:start_date]) if params[:start_date].present?
        @ckb_transactions = @ckb_transactions.where('updated_at <= ?', params[:end_date]) if params[:end_date].present?
        @ckb_transactions = @ckb_transactions.where('block_number >= ?', params[:block_number]) if params[:block_number].present?
        @ckb_transactions = @ckb_transactions.where('block_number <= ?', params[:block_number]) if params[:block_number].present?
        file = CSV.generate do |csv|
          csv << ["TXn hash", "Blockno", "UnixTimestamp", "Method", "CKB In", "CKB OUT", "Other Cells In", "Other Cells Out", "TxnFee(CKB)", "TxnFee(USD)",
                  "date(UTC)", "current CKB balance"]
          @ckb_transactions.each_with_index do |ckb_transaction, index|
            row = [ckb_transaction.tx_hash, ckb_transaction.block_number, ckb_transaction.block_timestamp, "Transfer", "CKB In", "CKB OUT", "Other Cell In",
                   "Other Cell OUT", "TxnFee(CKB)", "TxnFee(USD)", ckb_transaction.updated_at, "current CKB balance"]
            csv << row
          end
        end
        send_data file, :type => 'text/csv; charset=utf-8; header=present', :disposition => "attachment;filename=ckb_transactions.csv"
      end

      private

      def validate_query_params
        validator = Validations::Address.new(params)

        if validator.invalid?
          errors = validator.error_object[:errors]
          status = validator.error_object[:status]

          render json: errors, status: status
        end
      end

      def pagination_params
        @page = params[:page] || 1
        @page_size = params[:page_size] || CkbTransaction.default_per_page
      end

      def json_result
        ckb_transaction_serializer = CkbTransactionsSerializer.new(@ckb_transactions, @options.merge(params: { previews: true, address: @address }))

        if QueryKeyUtils.valid_address?(params[:id])
          if @address.address_hash == @address.query_address
            ckb_transaction_serializer.serialized_json
          else
            ckb_transaction_serializer.serialized_json.gsub(@address.address_hash, @address.query_address)
          end
        else
          ckb_transaction_serializer.serialized_json
        end
      end

      def set_address_transactions
        @address = Address.find_address!(params[:id])
        raise Api::V1::Exceptions::AddressNotFoundError if @address.is_a?(NullAddress)

      end

    end
  end
end
