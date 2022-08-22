module Api
  module V2
    class NFT::ItemsController < BaseController
      before_action :find_collection
      def index
        scope = TokenItem.all
        @owner = Address.find_address!(params[:owner]) if params[:owner]
        scope = scope.where(collection_id: @collection.id) if @collection

        scope = scope.where(standard) if params[:standard]
        scope = scope.where(owner_id: @owner.id) if params[:owner]
        @pagy, @items = pagy(scope)
        render json: {
          data: @items,
          pagination: pagy_metadata(@pagy)
        }
      end

      def show
        @collection = TokenCollection.find params[:collection_id]
        @item = @collection.items.find_by token_id: params[:id]
        if @item
          render json: @item.as_json.merge(collection: @item.collection.as_json)
        else
          head :not_found
        end
      end

      protected

      def find_collection
        @collection = TokenCollection.find_by_id params[:collection_id] if params[:collection_id].present?
      end
    end
  end
end
