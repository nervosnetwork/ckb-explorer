module Api
  module V1
    class AddressTransactionsController < ApplicationController
      before_action :validate_pagination_params

      def show
        expires_in 10.seconds, public: true, must_revalidate: true, stale_while_revalidate: 5.seconds
        json = Addresses::CkbTransactions.run!(
          { request:,
            key: params[:id], sort: params[:sort],
            page: params[:page], page_size: params[:page_size] },
        )
        render json:
      end

      def download_csv
        address = Addresses::Explore.run!(key: params[:id])
        raise Api::V1::Exceptions::AddressNotFoundError if address.is_a?(NullAddress)

        args = params.permit(:id, :start_date, :end_date, :start_number, :end_number, address_transaction: {}).
          merge(address_id: address.map(&:id))
        file = CsvExportable::ExportAddressTransactionsJob.perform_now(args.to_h)

        send_data file, type: "text/csv; charset=utf-8; header=present",
                        disposition: "attachment;filename=ckb_transactions.csv"
      end
    end
  end
end
