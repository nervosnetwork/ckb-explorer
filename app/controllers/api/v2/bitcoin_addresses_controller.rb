module Api
  module V2
    class BitcoinAddressesController < BaseController
      before_action :set_pagination_params, only: %i[rgb_cells]
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

      def rgb_cells
        expires_in 1.minute, public: true, must_revalidate: true, stale_while_revalidate: 10.seconds

        address = Addresses::Explore.run!(key: params[:id])
        address_ids = address.map(&:id)

        bitcoin_vouts = BitcoinVout.joins(:cell_output).
          where(cell_outputs: { status: "live" }, bitcoin_vouts: { address_id: address_ids }).
          select(:bitcoin_transaction_id, :index).
          group(:bitcoin_transaction_id, :index).
          page(@page).per(@page_size)

        transaction_ids = bitcoin_vouts.map(&:bitcoin_transaction_id).uniq
        transactions = BitcoinTransaction.where(id: transaction_ids).index_by(&:id)

        cells = bitcoin_vouts.each_with_object({}) do |vout, hash|
          tx = transactions[vout.bitcoin_transaction_id]
          vouts = BitcoinVout.where(bitcoin_transaction_id: vout.bitcoin_transaction_id, index: vout.index).includes(:cell_output).where(
            cell_outputs: { status: "live" },
          )
          hash[[tx.txid, vout.index]] = vouts.map { |v| CellOutputSerializer.new(v.cell_output).serializable_hash }
        end

        render json: { data: { rgb_cells: cells }, meta: { total: bitcoin_vouts.total_count, page_size: @page_size } }
      end

      private

      def set_pagination_params
        @page = params.fetch(:page, 1)
        @page_size = params.fetch(:page_size, CellOutput.default_per_page)
      end
    end
  end
end
