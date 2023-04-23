module Api
  module V2
    class NFT::CollectionsController < BaseController
      def index
        asc_or_desc = params[:asc_or_desc] || 'desc'
        order_by = params[:order_by] || 'id'
        head :not_found and return unless order_by.in? %w[id holders_count items_count]

        collections = TokenCollection
        collections = collections.where(standard: params[:type]) if params[:type].present?
        collections = collections
          .order(params[:order_by]: order_by)
          .page(@page).per(@page_size).fast_page

        @pagy, @collections = pagy(collections).fast_page
        render json: {
          data: @collections,
          pagination: pagy_metadata(@pagy)
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
