module Api
  module V2
    class RgbLiveCellsController < BaseController
      before_action :set_pagination_params
      def index
        code_hash = params.fetch("code_hash", nil)

        if CkbSync::Api.instance.rgbpp_code_hash.include?(code_hash)
          scope = BitcoinVout.bound.without_op_return.includes(cell_output: [:lock_script]).
            where(cell_outputs: { status: "live" }, lock_scripts: { code_hash: }).
            page(@page).per(@page_size, max_per_page: 1000).fast_page
          total_count = scope.total_count
          cells = scope.map { { tx_hash: _1.cell_output.tx_hash, cell_index: _1.cell_output.cell_index } }
        else
          total_count = 0
          cells = CellOutput.none
        end

        render json: { cells:, meta: { total: total_count, page_size: @page_size } }
      end

      private

      def set_pagination_params
        @page = params.fetch(:page, 1)
        @page_size = params.fetch(:page_size, CellOutput.default_per_page)
      end
    end
  end
end
