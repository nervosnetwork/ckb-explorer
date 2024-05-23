module Api
  module V2
    class BitcoinAddressesController < BaseController
      def show
        expires_in 1.minute, public: true, must_revalidate: true, stale_while_revalidate: 10.seconds

        address = Addresses::Explore.run!(key: params[:id])
        unbound_live_cells_count = BitcoinVout.includes(:ckb_address, :cell_output).where(
          ckb_address: { id: address.map(&:id) },
          bitcoin_vouts: { status: "unbound" },
          cell_outputs: { status: "live" },
        ).count

        render json: { unbound_live_cells_count: }
      end
    end
  end
end
