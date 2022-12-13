module Api
  module V2
    class Cota::IssuersController < BaseController

      def index
      end

      def show
        address = params[:id]
        lock_script = get_lock_hash
        res = CotaAggregator.instance.get_issuer_info(lock_script)
        render json: res
      end

      def minted
        lock_script = get_lock_hash
        res = CotaAggregator.instance.get_mint_cota_nft(
          lock_script: lock_script,
          page: params[:page],
          page_size: params[:page_size]
        )
        render json: {
          data: res['nfts'],
          pagination: {
            total: res['total'],
            page_size: res['page_size']
          }
        }
      end
      protected
      def get_lock_hash(address=params[:id])
        if address =~ /\A0x/
          address
        else
          parsed = CkbUtils.parse_address(address)
          parsed.script.compute_hash
        end
      end
    end
  end
end
