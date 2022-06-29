module Api
  module V2
    class NFT::CollectionsController < BaseController
      def index
        @pagy, @collections = pagy(TokenCollection)
        render json: { 
              data: @collections,
               pagination: pagy_metadata(@pagy) 
              }
      end      

      def show
        @collection = TokenCollection.find params[:id]
        render json: @collection
      end
    end
  end
end
