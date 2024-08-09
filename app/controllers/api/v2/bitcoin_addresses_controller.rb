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

      def udt_accounts
        expires_in 1.minute, public: true, must_revalidate: true, stale_while_revalidate: 10.seconds

        address = Addresses::Explore.run!(key: params[:id])
        address_ids = address.map(&:id)

        cell_types = %w(udt xudt xudt_compatible)
        cell_outputs = CellOutput.live.includes(:bitcoin_vout).where(cell_outputs: { address_id: address_ids, cell_type: cell_types }).
          where.not(bitcoin_vouts: { status: "unbound" }).group(:cell_type, :type_hash).sum(:udt_amount)

        udt_accounts = cell_outputs.map do |k, v|
          udt = Udt.find_by(type_hash: k[1], published: true)
          next unless udt

          {
            symbol: udt.symbol,
            decimal: udt.decimal,
            amount: v,
            type_hash: k[1],
            udt_icon_file: udt.icon_file,
            udt_type: udt.udt_type,
            udt_type_script: udt.type_script,
          }
        end.compact

        render json: { data: { udt_accounts: } }
      end

      private

      def set_pagination_params
        @page = params.fetch(:page, 1)
        @page_size = params.fetch(:page_size, CellOutput.default_per_page)
      end
    end
  end
end
