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
        if params[:id] =~ /\A\d+\z/
          @collection = TokenCollection.find params[:id]
        else
          @type_script = TypeScript.find_by script_hash: params[:id]
          @collection = TokenCollection.find_by type_script_id: @type_script.id
        end
        
        if @collection
          render json: @collection
        else
          head :not_found
        end
      end
    end
  end
end
