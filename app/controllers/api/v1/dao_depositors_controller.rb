module Api
  module V1
    class DaoDepositorsController < ApplicationController
      def index
        addresses = Address.select(:id, :address_hash, :dao_deposit, :average_deposit_time).where(is_depositor: true).where("dao_deposit > 0").order(dao_deposit: :desc).limit(100)

        render json: DaoDepositorSerializer.new(addresses)
      end

      def download_csv
        args = params.permit(:start_date, :end_date, :start_number, :end_number)
        file = CsvExportable::ExportDaoDepositorsJob.perform_now(args.to_h)

        send_data file, type: "text/csv; charset=utf-8; header=present",
                        disposition: "attachment;filename=dao_depositors.csv"
      end
    end
  end
end
