module Api
  module V1
    class FungibleTokensController < ApplicationController
      before_action :validate_query_params, only: :show
      before_action :validate_pagination_params, :pagination_params, only: :index

      def index
        scope = Udt.includes(:xudt_tag).where(published: true, udt_type: %i[ssri xudt xudt_compatible sudt])

        if params[:tags].present?
          tags = parse_tags
          if params[:union].present?
            scope = scope.joins(:xudt_tag).where("xudt_tags.tags && ARRAY[?]::varchar[]", tags).select("udts.*") unless tags.empty?
          else
            scope = scope.joins(:xudt_tag).where("xudt_tags.tags @> array[?]::varchar[]", tags).select("udts.*") unless tags.empty?
          end
        end

        if stale?(scope)
          expires_in 1.minute, public: true

          udts = sort_udts(scope).page(@page).per(@page_size).fast_page
          options = FastJsonapi::PaginationMetaGenerator.new(
            request:,
            records: udts,
            page: @page,
            page_size: @page_size,
          ).call

          render json: UdtSerializer.new(udts, options)
        end
      end

      def show
        udt = Udt.find_by!(type_hash: params[:id], published: true)
        render json: UdtSerializer.new(udt)
      rescue ActiveRecord::RecordNotFound
        raise Api::V1::Exceptions::UdtNotFoundError
      end

      def download_csv
        args = params.permit(:id, :start_date, :end_date, :start_number, :end_number, udt: {})
        file = CsvExportable::ExportUdtTransactionsJob.perform_now(args.to_h)

        send_data file, type: "text/csv; charset=utf-8; header=present",
                        disposition: "attachment;filename=udt_transactions.csv"
      rescue ActiveRecord::RecordNotFound
        raise Api::V1::Exceptions::UdtNotFoundError
      end

      private

      def validate_query_params
        validator = Validations::Udt.new(params)

        if validator.invalid?
          errors = validator.error_object[:errors]
          status = validator.error_object[:status]

          render json: errors, status:
        end
      end

      def pagination_params
        @page = params[:page] || 1
        @page_size = params[:page_size] || Udt.default_per_page
      end

      def sort_udts(records)
        sort, order = params.fetch(:sort, "id.desc").split(".", 2)
        sort =
          case sort
          when "created_time" then "block_timestamp"
          when "transactions" then "h24_ckb_transactions_count"
          when "addresses_count" then "addresses_count"
          else "id"
          end

        if order.nil? || !order.match?(/^(asc|desc)$/i)
          order = "asc"
        end

        records.order("#{sort} #{order}").order("full_name ASC, id ASC")
      end

      def parse_tags
        tags = params[:tags].split(",")
        tags & XudtTag::VALID_TAGS
      end
    end
  end
end
