module Api
  module V2
    module NFT
      class HoldersController < BaseController
        def index
          token_items = find_collection.items.joins(:owner)

          if params[:address_hash].present?
            token_items = token_items.where(owner: { address_hash: params[:address_hash] })
          end

          counts = sort_token_items(token_items).group(:address_hash).count

          render json: { data: counts }
        rescue ActiveRecord::RecordNotFound
          raise Api::V2::Exceptions::TokenCollectionNotFoundError
        end

        private

        def find_collection
          if QueryKeyUtils.valid_hex?(params[:collection_id])
            TokenCollection.find_by_type_hash(params[:collection_id])
          else
            TokenCollection.find(params[:collection_id])
          end
        end

        def sort_token_items(records)
          sort, order = params.fetch(:sort, "").split(".", 2)
          # ActiveRecord calculations automatically converts count(*) to count_all
          # https://github.com/rails/rails/blob/v7.0.4/activerecord/lib/active_record/relation/calculations.rb#L407
          sort = sort.eql?("quantity") ? "count_all" : nil

          return records unless sort

          if order.nil? || !order.match?(/^(asc|desc)$/i)
            order = "asc"
          end

          records.order("#{sort} #{order}")
        end
      end
    end
  end
end
