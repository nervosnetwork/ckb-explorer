module Api
  module V2
    class NFT::CollectionsController < BaseController
      def index
        params[:sort] ||= "id.desc"

        order_by, asc_or_desc = params[:sort].split('.', 2)
        order_by = case order_by
        # TODO need to merge PR:  https://github.com/nervosnetwork/ckb-explorer/pull/1266
        when 'transactions' then 'h24_transactions_count'
        when 'holder' then 'holders_count'
        when 'minted' then 'items_count'
        else order_by
        end

        head :not_found and return unless order_by.in? %w[id holders_count items_count]

        collections = TokenCollection
        collections = collections.where(standard: params[:type]) if params[:type].present?
        collections = collections
          .order(order_by => asc_or_desc)
          .page(@page).per(@page_size).fast_page

        @pagy, @collections = pagy(collections)
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
