module Api
  module V1
    class UdtsController < ApplicationController
      before_action :validate_query_params, only: :show
      before_action :validate_pagination_params, :pagination_params, only: :index

      def index
        udts = Udt.sudt

        if stale?(udts)
          expires_in 30.minutes, public: true, stale_while_revalidate: 10.minutes, stale_if_error: 10.minutes

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

      def update
        udt = Udt.find_by!(type_hash: params[:id])
        attrs = {
          symbol: params[:symbol],
          full_name: params[:full_name],
          decimal: params[:decimal],
          description: params[:description],
          operator_website: params[:operator_website],
          icon_file: params[:icon_file],
          uan: params[:uan],
          display_name: params[:display_name],
          email: params[:email],
          published: true,
        }
        if udt.email.blank?
          raise Api::V1::Exceptions::UdtInfoInvalidError.new("Email can't be blank") if params[:email].blank?

          udt.update!(attrs)
        else
          raise Api::V1::Exceptions::UdtVerificationNotFoundError if udt.udt_verification.nil?

          udt.udt_verification.validate_token!(params[:token])
          udt.update!(attrs.except(:email))
        end
        render json: :ok
      rescue ActiveRecord::RecordNotFound
        raise Api::V1::Exceptions::UdtNotFoundError
      rescue ActiveRecord::RecordInvalid => e
        raise Api::V1::Exceptions::UdtInfoInvalidError.new(e)
      rescue UdtVerification::TokenExpiredError
        raise Api::V1::Exceptions::TokenExpiredError
      rescue UdtVerification::TokenNotMatchError
        raise Api::V1::Exceptions::TokenNotMatchError
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

        records.order("#{sort} #{order}")
      end
    end
  end
end
