module Addresses
  class LiveCells < ActiveInteraction::Base
    include Api::V1::Exceptions

    object :request, class: ActionDispatch::Request
    string :key, default: nil
    string :sort, default: "block_timestamp.desc"
    integer :page, default: 1
    integer :page_size, default: CellOutput.default_per_page

    def execute
      address = Explore.run!(key:)
      raise AddressNotFoundError if address.is_a?(NullAddress)

      order_by, asc_or_desc = live_cells_ordering
      records = CellOutput.live.where(address_id: address.map(&:id)).
        order(order_by => asc_or_desc).
        page(page).per(page_size).fast_page
      options = FastJsonapi::PaginationMetaGenerator.new(
        request:, records:, page:, page_size:,
      ).call

      CellOutputSerializer.new(records, options).serialized_json
    end

    private

    def live_cells_ordering
      sort_by, sort_order = sort.split(".", 2)
      if sort_order.nil? || !sort_order.match?(/^(asc|desc)$/i)
        sort_order = "asc"
      end

      [sort_by, sort_order]
    end
  end
end
