module Api
  module V2
    class BitcoinAddressesController < BaseController
      def show
        expires_in 1.minute, public: true, must_revalidate: true, stale_while_revalidate: 10.seconds

        address = Addresses::Explore.run!(key: params[:id])
        live_cells_count = ->(status) do
          BitcoinVout.includes(:ckb_address, :cell_output).where(
            ckb_address: { id: address.map(&:id) },
            bitcoin_vouts: { status: },
            cell_outputs: { status: "live" },
          ).count
        end
        unbound_live_cells_count = live_cells_count.call("unbound")
        bound_live_cells_count = live_cells_count.call("bound")

        render json: { unbound_live_cells_count:, bound_live_cells_count: }
      end
    end
  end
end
