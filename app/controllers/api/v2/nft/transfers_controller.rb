require "csv"
module Api
  module V2
    module NFT
      class TransfersController < BaseController
        def index
          if params[:collection_id].present?
            if /\A\d+\z/.match?(params[:collection_id])
              collection = TokenCollection.find params[:collection_id]
            else
              collection = TokenCollection.find_by_sn params[:collection_id]
            end
          end

          if collection && params[:token_id]
            item = collection.items.find_by token_id: params[:token_id]
          end

          if item
            scope = item.transfers
          elsif collection
            scope = collection.transfers
          else
            scope = TokenTransfer.all
          end

          from = Address.find_by_address_hash(params[:from]) if params[:from]
          to = Address.find_by_address_hash(params[:to]) if params[:to]
          scope = scope.where(from: from) if from
          scope = scope.where(to: to) if to
          scope = scope.where(action: params[:transfer_action]) if params[:transfer_action]
          scope = scope.order(transaction_id: :desc)
          pagy, token_transfers = pagy(scope)

          render json: {
            data: token_transfers,
            pagination: pagy
          }
        end

        def show
          token_transfer = TokenTransfer.find(params[:id])
          render json: token_transfer
        end

        def download_csv
          args = params.permit(:start_date, :end_date, :start_number, :end_number, :collection_id)
          file = CsvExportable::ExportNFTTransactionsJob.perform_now(args.to_h)

          send_data file, type: "text/csv; charset=utf-8; header=present",
                          disposition: "attachment;filename=token_transfers.csv"
        end
      end
    end
  end
end
