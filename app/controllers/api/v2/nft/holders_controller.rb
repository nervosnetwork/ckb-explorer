module Api
  module V2
    class NFT::HoldersController < BaseController
      before_action :find_collection
      def index
        @counts = @collection.items.joins(:owner).group(:address_hash).count
        # @pagy, @addresses = pagy(scope)
        render json: {
          data: @counts
          # pagination: pagy_metadata(@pagy)
        }
      end

      protected

      def find_collection
        @collection = TokenCollection.find_by_id params[:collection_id] if params[:collection_id].present?
      end
    end
  end
end
