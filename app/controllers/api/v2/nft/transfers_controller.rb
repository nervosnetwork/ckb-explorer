module Api
  module V2
    module NFT
      class TransfersController < BaseController
        def index
          scope = TokenTransfer.all

          if params[:collection_id].present?
            collection = find_collection(params[:collection_id])
            scope = collection.present? ? filtered_by_token_id(collection) : TokenTransfer.none
          end

          scope = apply_filters(scope)
          scope = scope.order(transaction_id: :desc)
          pagy, token_transfers = pagy(scope)

          render json: { data: token_transfers, pagination: pagy }
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

        private

        def find_collection(collection_id)
          if /\A\d+\z/.match?(collection_id)
            TokenCollection.find_by(id: collection_id)
          else
            TokenCollection.find_by(sn: collection_id)
          end
        end

        def filtered_by_token_id(collection)
          if params[:token_id].present?
            item = collection.items.find_by(token_id: params[:token_id])
            item.nil? ? TokenTransfer.none : item.transfers
          else
            collection.transfers
          end
        end

        def apply_filters(scope)
          scope = scope.where(from: find_address(params[:from])) if params[:from].present?
          scope = scope.where(to: find_address(params[:to])) if params[:to].present?
          if params[:address_hash].present?
            address = find_address(params[:address_hash])
            scope = scope.where(from: address).or(scope.where(to: address))
          end
          scope = scope.where(action: params[:transfer_action]) if params[:transfer_action].present?
          scope = scope.includes(:ckb_transaction).where(ckb_transaction: { tx_hash: params[:tx_hash] }) if params[:tx_hash].present?

          scope
        end

        def find_address(address_hash)
          Address.find_by_address_hash(address_hash)
        end
      end
    end
  end
end
