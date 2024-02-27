module Api
  module V2
    class NFT::ItemsController < BaseController
      before_action :find_collection
      def index
        scope = TokenItem.includes(:collection)
        if params[:owner]
          @owner = Address.find_address!(params[:owner])
          scope = scope.where(owner_id: @owner.id)
        end
        scope = scope.where(collection_id: @collection.id) if @collection
        scope = scope.where(collection: { standard: params[:standard] }) if params[:standard]
        scope = scope.where(token_id: params[:token_id]) if params[:token_id]
        scope = scope.order(token_id: :asc)
        pagy, items = pagy(scope)
        items = items.map do |i|
          j = i.as_json
          j["collection"] = i.collection.as_json
          j
        end
        render json: {
          data: items,
          pagination: pagy_metadata(pagy),
        }
      end

      def show
        if !@collection
          return head(:not_found)
        end

        token_id = parse_hex_token_id(params[:id])
        item = @collection.items.find_by(token_id:)
        if item
          render json: item.as_json.merge(collection: item.collection.as_json)
        else
          head :not_found
        end
      end

      protected

      def find_collection
        if params[:collection_id].present?
          @collection = if /\A\d+\z/.match?(params[:collection_id])
                          TokenCollection.find params[:collection_id]
                        else
                          TokenCollection.find_by_sn params[:collection_id]
                        end
        end
      end

      def parse_hex_token_id(hex_id)
        if hex_id.start_with?("0x")
          hex_id.hex
        else
          hex_id
        end
      end
    end
  end
end
