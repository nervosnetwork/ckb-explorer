module Api
  module V2
    module Portfolio
      class CkbTransactionsController < BaseController
        before_action :validate_jwt!

        def index
          expires_in 15.minutes, public: true, stale_while_revalidate: 5.minutes, stale_if_error: 5.minutes
          json = Users::CkbTransactions.run!(transaction_list_params.merge({ user: current_user, request: }))

          render json:
        end

        def download_csv
          args = download_params.merge(address_ids: current_user.address_ids)
          file = CsvExportable::ExportPortfolioTransactionsJob.perform_now(args.to_h)

          send_data file, type: "text/csv; charset=utf-8; header=present",
                          disposition: "attachment;filename=portfolio_ckb_transactions.csv"
        end

        private

        def transaction_list_params
          params.permit(:address_hash, :tx_hash, :sort, :page, :page_size)
        end

        def download_params
          params.permit(:start_date, :end_date, :start_number, :end_number)
        end
      end
    end
  end
end
