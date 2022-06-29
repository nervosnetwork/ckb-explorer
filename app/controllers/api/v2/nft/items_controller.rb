module Api
  module V2
    class NFT::ItemsController < BaseController
      before_action :find_collection
      def index
        scope = TokenItem.all
        scope = scope.where(collection_id: @collection.id) if @collection
        scope = scope.where(standard) if params[:standard]
        @pagy, @collections = pagy(scope)
        render json: { 
          data: @collections,
          pagination: pagy_metadata(@pagy) 
        }
      end      

      def show
        @collection = TokenCollection.find params[:collection_id]
        @item = @collection.items.find_by token_id: params[:id]

        render json: @item.as_json.merge(collection: @item.collection.as_json)
      end
      
      protected
      def find_collection
        @collection = TokenCollection.find_by_id params[:collection_id] if params[:collection_id].present?
      end
    end
  end
end
