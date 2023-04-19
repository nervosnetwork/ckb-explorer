module Api
  module V2
    class NFT::TransfersController < BaseController
      # GET /token_transfers
      def index
        if params[:collection_id].present?
          if /\A\d+\z/.match?(params[:collection_id])
            @collection = TokenCollection.find params[:collection_id]
          else
            @collection = TokenCollection.find_by_sn params[:collection_id]
          end
        end
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
        @pagy, @token_transfers = pagy(scope).fast_page

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
    end
  end
end
