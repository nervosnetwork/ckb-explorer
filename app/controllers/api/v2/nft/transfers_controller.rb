require 'csv'
module Api
  module V2
    class NFT::TransfersController < BaseController
      before_action :set_token_transfer, only: [:download_csv]

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
        scope = scope.order(transaction_id: :desc)
        # scope = scope.order(cell_id: :desc)
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

        token_transfers = TokenTransfer
          .joins(:item, :ckb_transaction)
          .includes(:ckb_transaction, :from, :to)
          .where('token_items.collection_id = ?', @collection.id )

        token_transfers = token_transfers.where('ckb_transactions.block_timestamp >= ?', DateTime.strptime(params[:start_date], '%Y-%m-%d').to_time.to_i * 1000 ) if params[:start_date].present?
        token_transfers = token_transfers.where('ckb_transactions.block_timestamp <= ?', DateTime.strptime(params[:end_date], '%Y-%m-%d').to_time.to_i * 1000 ) if params[:end_date].present?
        token_transfers = token_transfers.where('ckb_transactions.block_number >= ?', params[:start_number]) if params[:start_number].present?
        token_transfers = token_transfers.where('ckb_transactions.block_number <= ?', params[:end_number]) if params[:end_number].present?

        token_transfers = token_transfers
          .order('token_transfers.id desc')
          .limit(5000)

        file = CSV.generate do |csv|
          csv << ['Txn hash', 'Blockno', 'UnixTimestamp', 'NFT ID', 'Method', 'NFT from', 'NFT to', 'TxnFee(CKB)', 'date(UTC)']
          token_transfers.find_each do |transfer|
            ckb_transaction = transfer.ckb_transaction
            row = [ckb_transaction.tx_hash, ckb_transaction.block_number, ckb_transaction.block_timestamp,
                   transfer.item.token_id, transfer.action, transfer.from.address_hash, transfer.to.address_hash,
                   ckb_transaction.transaction_fee, ckb_transaction.block_timestamp]
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
