module Api
  module V2
    class NFT::CollectionsController < BaseController
      def index
        pagy, collections = pagy(TokenCollection.order(id: :desc))
        render json: {
          data: collections,
          pagination: pagy_metadata(pagy)
        }
      end

      def show
        if params[:id] =~ /\A\d+\z/
          collection = TokenCollection.find params[:id]
        else
          collection = TokenCollection.find_by_sn params[:id]
        end

        if collection
          render json: collection
        else
          head :not_found
        end
      end

    end
  end
end
