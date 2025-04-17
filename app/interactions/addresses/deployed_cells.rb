module Addresses
  class DeployedCells < ActiveInteraction::Base
    include Api::V1::Exceptions

    object :request, class: ActionDispatch::Request
    string :key, default: nil
    string :sort, default: "block_timestamp.desc"
    integer :page, default: 1
    integer :page_size, default: CellOutput.default_per_page

    def execute
      address = Explore.run!(key:)
      raise AddressNotFoundError if address.is_a?(NullAddress)

      order_by, asc_or_desc = deployed_cells_ordering
      deployed_cell_output_ids = Contract.joins(:deployed_cell_output).where(cell_outputs: { address: address.map(&:id) }).pluck(:deployed_cell_output_id)
      records = CellOutput.where(id: deployed_cell_output_ids).order(order_by => asc_or_desc).
        page(page).per(page_size).fast_page

      options = FastJsonapi::PaginationMetaGenerator.new(request:, records:, page:, page_size:).call
      CellOutputSerializer.new(records, options).serialized_json
    end

    private

    def deployed_cells_ordering
      sort_by, sort_order = sort.split(".", 2)
      if sort_order.nil? || !sort_order.match?(/^(asc|desc)$/i)
        sort_order = "asc"
      end

      [sort_by, sort_order]
    end
  end
end
