module Api
  module V1
    class OmigaInscriptionsController < ApplicationController
      before_action :validate_query_params, only: :show
      before_action :validate_pagination_params, :pagination_params,
                    only: :index

      def index
        pre_udt_hashes = OmigaInscriptionInfo.where.not(pre_udt_hash: nil).pluck(:pre_udt_hash)
        udts = Udt.joins(:omiga_inscription_info).where.not(
          "omiga_inscription_infos.mint_status = 1 and omiga_inscription_infos.udt_hash IN (?)", pre_udt_hashes
        )

        if stale?(udts)
          udts = sort_udts(udts).page(@page).per(@page_size).fast_page
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
        udt =
          if params[:status] == "closed"
            Udt.joins(:omiga_inscription_info).where(
              "omiga_inscription_infos.type_hash = ? and omiga_inscription_infos.mint_status = 1", params[:id]
            ).first
          else
            Udt.joins(:omiga_inscription_info).where(
              "udts.type_hash = ? or omiga_inscription_infos.type_hash = ?", params[:id], params[:id]
            ).order("block_timestamp DESC").first
          end

        if udt.nil?
          raise Api::V1::Exceptions::UdtNotFoundError
        else
          render json: UdtSerializer.new(udt)
        end
      end

      def download_csv
        args = params.permit(:id, :start_date, :end_date, :start_number,
                             :end_number, udt: {})
        file = CsvExportable::ExportOmigaInscriptionTransactionsJob.perform_now(args.to_h)

        send_data file, type: "text/csv; charset=utf-8; header=present",
                        disposition: "attachment;filename=inscription_transactions.csv"
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
          else sort
          end

        if order.nil? || !order.match?(/^(asc|desc)$/i)
          order = "asc"
        end

        if sort == "mint_status"
          records.joins(:omiga_inscription_info).order("omiga_inscription_infos.mint_status #{order}")
        else
          records.order("#{sort} #{order}")
        end
      end
    end
  end
end
