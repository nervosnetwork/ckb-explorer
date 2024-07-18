module Api
  module V2
    class RgbLiveCellsController < BaseController
      before_action :set_pagination_params
      def index
        code_hash = params.fetch("code_hash", nil)
        cell_outputs =
          if CkbSync::Api.instance.rgbpp_code_hash.include?(code_hash)
            CellOutput.live.includes(:lock_script).where(lock_scripts: { code_hash: }).page(@page).per(@page_size).fast_page
          else
            CellOutput.none
          end
        total_count = cell_outputs.present? ? cell_outputs.total_count : 0
        outpoints = cell_outputs.pluck(:tx_hash, :cell_index)

        render json: { data: outpoints, meta: { total: total_count, page_size: @page_size } }
      end

      private

      def set_pagination_params
        @page = params.fetch(:page, 1)
        @page_size = params.fetch(:page_size, CellOutput.default_per_page)
      end
    end
  end
end
