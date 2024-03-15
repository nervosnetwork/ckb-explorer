module Api
  module V1
    class AddressLiveCellsController < ApplicationController
      before_action :validate_pagination_params, :pagination_params

      def show
        expires_in 1.minutes, public: true, must_revalidate: true, stale_while_revalidate: 10.seconds

        address = Address.find_address!(params[:id])
        raise Api::V1::Exceptions::AddressNotFoundError if address.is_a?(NullAddress)

        order_by, asc_or_desc = live_cells_ordering
        @addresses = address.cell_outputs.live.order(order_by => asc_or_desc).page(@page).per(@page_size).fast_page
        options = FastJsonapi::PaginationMetaGenerator.new(
          request:,
          records: @addresses,
          page: @page,
          page_size: @page_size,
        ).call
        render json: CellOutputSerializer.new(@addresses, options).serialized_json
      end

      private

      def pagination_params
        @page = params[:page] || 1
        @page_size = params[:page_size] || CellOutput.default_per_page
      end

      def live_cells_ordering
        sort, order = params.fetch(:sort, "block_timestamp.desc").split(".", 2)
        if order.nil? || !order.match?(/^(asc|desc)$/i)
          order = "asc"
        end

        [sort, order]
      end
    end
  end
end
