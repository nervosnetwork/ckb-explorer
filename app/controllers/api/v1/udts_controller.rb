require "csv"
module Api
  module V1
    class UdtsController < ApplicationController
      before_action :validate_query_params, only: :show
      before_action :validate_pagination_params, :pagination_params, only: :index

      def index
        udts = Udt.sudt

        params[:sort] ||= "id.desc"

        order_by, asc_or_desc = params[:sort].split(".", 2)
        order_by =
          case order_by
             when "created_time" then "block_timestamp"
             # current we don't support this in DB
             # need a new PR https://github.com/nervosnetwork/ckb-explorer/pull/1266/
             # when 'transactions' then 'h24_ckb_transactions_count'
             else order_by
          end

        head :not_found and return unless order_by.in? %w[id addresses_count block_timestamp]

        udts = udts.order(order_by => asc_or_desc).
          page(@page).per(@page_size).fast_page

        options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: udts, page: @page,
                                                           page_size: @page_size).call
        render json: UdtSerializer.new(udts, options)
      end

      def show
        udt = Udt.find_by!(type_hash: params[:id], published: true)

        render json: UdtSerializer.new(udt)
      rescue ActiveRecord::RecordNotFound
        raise Api::V1::Exceptions::UdtNotFoundError
      end

      def download_csv
        args = params.permit(:id, :start_date, :end_date, :start_number, :end_number, udt: {})
        data = ExportUdtTransactionsJob.perform_now(args.to_h)

        file =
          CSV.generate do |csv|
            csv << [
              "Txn hash", "Blockno", "UnixTimestamp", "Method",
              "Token In", "Token In Name", "Token OUT", "Token OUT Name",
              "Token From", "Token To", "TxnFee(CKB)", "date(UTC)"
            ]
            data.each { |row| csv << row }
          end

        send_data file, type: "text/csv; charset=utf-8; header=present",
                        disposition: "attachment;filename=udt_transactions.csv"
      rescue ActiveRecord::RecordNotFound => e

        raise Api::V1::Exceptions::UdtNotFoundError
      end

      private

      def validate_query_params
        validator = Validations::Udt.new(params)

        if validator.invalid?
          errors = validator.error_object[:errors]
          status = validator.error_object[:status]

          render json: errors, status: status
        end
      end

      def pagination_params
        @page = params[:page] || 1
        @page_size = params[:page_size] || Udt.default_per_page
      end
    end
  end
end
