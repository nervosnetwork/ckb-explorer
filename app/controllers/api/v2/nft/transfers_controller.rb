require 'csv'
module Api
  module V2
    class NFT::TransfersController < BaseController
      before_action :set_token_transfer, only: [:show, :download_csv]

      # GET /token_transfers
      def index
        if @collection && params[:token_id]
          @item = @collection.items.find_by token_id: params[:token_id]
        end

        if @item
          scope = @item.transfers
        elsif @collection
          scope = @collection.transfers
        else
          scope = TokenTransfer.all
        end

        @from = Address.find_by_address_hash(params[:from]) if params[:from]
        @to = Address.find_by_address_hash(params[:to]) if params[:to]
        scope = scope.where(from: @from) if @from
        scope = scope.where(to: @to) if @to
        scope = scope.order(transaction_id: :desc)
        # scope = scope.order(cell_id: :desc)
        @pagy, @token_transfers = pagy(scope)

        render json: {
          data: @token_transfers,
          pagination: @pagy
        }
      end

      # GET /token_transfers/1
      def show
        @token_transfer = TokenTransfer.find(params[:id])
        render json: @token_transfer
      end

      def download_csv
        file = CSV.generate do |csv|
          csv << ["Txn hash", "Blockno", "UnixTimestamp", "Method", "CKB In", "CKB OUT", "Other Cell In", "Other Cell Out", "TxnFee(CKB)", "TxnFee(USD)", "date(UTC)"]
          @collection.transfers.each do |transfer|
            ckb_transaction = transfer.ckb_transaction
            row = [ckb_transaction.tx_hash, ckb_transaction.block_number, ckb_transaction.block_timestamp, "Method", "ckb in", "ckb out", "TxnFee(CKB)", "TxnFee(USD)", ckb_transaction.updated_at]
            csv << row
          end
        end
        send_data file, :type => 'text/csv; charset=utf-8; header=present', :disposition => "attachment;filename=token_transfers.csv"
      end

      private
      def set_token_transfer
        if params[:collection_id].present?
          if /\A\d+\z/.match?(params[:collection_id])
            @collection = TokenCollection.find params[:collection_id]
          else
            @collection = TokenCollection.find_by_sn params[:collection_id]
          end
        end
      end

    end
  end
end
