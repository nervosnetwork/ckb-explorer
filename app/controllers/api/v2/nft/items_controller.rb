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
        if !@collection
          return head(:not_found)
        end
        @item = @collection.items.find_by token_id: params[:id]
        if @item
          render json: @item.as_json.merge(collection: @item.collection.as_json)
        else
          head :not_found
        end
      end

      protected

      def find_collection
        if params[:collection_id].present?
          if params[:collection_id] =~ /\A\d+\z/
            @collection = TokenCollection.find params[:collection_id]
          else
            @type_script = TypeScript.find_by script_hash: params[:collection_id]
            @collection = TokenCollection.find_by type_script_id: @type_script.id
          end
        end
      end
    end
  end
end
