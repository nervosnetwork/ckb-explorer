module Api
  module V2
    class Cota::IssuersController < BaseController

      def index
      end

      # GET /token_transfers/1
      def show
        address = params[:id]
        lock_script = if address =~ /\A0x/
          address
        else
          parsed = CkbUtils.parse_address(address)
          parsed.script.compute_hash
        end
        res = CotaAggregator.instance.get_issuer_info(lock_script)
        render json: res
      end
    end
  end
end
