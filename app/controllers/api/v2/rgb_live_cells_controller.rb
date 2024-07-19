module Api
  module V2
    class RgbLiveCellsController < BaseController
      before_action :set_pagination_params
      def index
        code_hash = params.fetch("code_hash", nil)

        if CkbSync::Api.instance.rgbpp_code_hash.include?(code_hash)
          scope = CellOutput.live.includes(:lock_script).where(lock_scripts: { code_hash: })
          # The average block time of BTC is 10 minutes longer
          total_count = Rails.cache.fetch(scope.cache_key, expires_in: 5.minutes) { scope.count }
          scope = scope.page(@page).per(@page_size, max_per_page: 1000).fast_page
          cells = scope.map { { tx_hash: _1.tx_hash, cell_index: _1.cell_index } }
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
