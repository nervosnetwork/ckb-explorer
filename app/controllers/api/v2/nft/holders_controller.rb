module Api
  module V2
    class NFT::HoldersController < BaseController
      before_action :find_collection
      def index
        if !@collection
          return head(:not_found)
        end
        counts = @collection.items.joins(:owner).group(:address_hash).count
        # @pagy, @addresses = pagy(scope)
        render json: {
          data: counts
          # pagination: pagy_metadata(@pagy)
        }
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
