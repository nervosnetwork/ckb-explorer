module Api
  module V2
    module NFT
      class CollectionsController < BaseController
        def index
          scope = TokenCollection.includes(:items, :creator, :type_script)
          if params[:type].present?
            scope = scope.where(standard: params[:type])
          end
          pagy, collections = pagy(sort_collections(scope))

          render json: {
            data: collections,
            pagination: pagy_metadata(pagy)
          }
        end

        def show
          if /\A\d+\z/.match?(params[:id])
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

        private

        def sort_collections(records)
          sort, order = params.fetch(:sort, "id.desc").split(".", 2)
          sort =
            case sort
            when "transactions" then "h24_ckb_transactions_count"
            when "holder" then "holders_count"
            when "minted" then "items_count"
            else "id"
            end

          if order.nil? || !order.match?(/^(asc|desc)$/i)
            order = "asc"
          end

          records.order("#{sort} #{order}")
        end
      end
    end
  end
end
