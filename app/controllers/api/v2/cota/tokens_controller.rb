module Api
  module V2
    class Cota::TokensController < BaseController

      def index
        class_id = params[:nft_class_id]
        token_id = params[:id]
        render json: res
      end

      def show

      end

      def claimed
        lock_hash = address_to_lock_hash(params[:owner])
        render json: CotaAggregator.instance.is_claimed(lock_script: lock_hash, cota_id: params[:nft_class_id], token_index: params[:id].to_i)
      end

      def sender
        lock_hash = address_to_lock_hash(params[:owner])
        render json: CotaAggregator.instance.get_cota_nft_sender(lock_script: lock_hash, cota_id: params[:nft_class_id], token_index: params[:id].to_i)
      end
    end
  end
end
