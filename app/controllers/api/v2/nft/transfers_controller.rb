module Api
  module V2
    class NFT::TransfersController < BaseController
      # GET /token_transfers
      def index
        if params[:collection_id].present?
          if params[:id] =~ /\A\d+\z/
            @collection = TokenCollection.find params[:collection_id]
          else
            @type_script = TypeScript.find_by script_hash: params[:collection_id]
            @collection = TokenCollection.find_by type_script_id: @type_script.id
          end
        end        
        @item = @collection.items.find_by token_id: params[:item_id] if params[:item_id]
        
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
        scope = scope.order(cell_id: :desc)
        @pagy, @token_transfers = pagy(scope)

        render json: {
          data:@token_transfers,
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
