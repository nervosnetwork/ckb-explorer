module Addresses
  class Info < ActiveInteraction::Base
    include Api::V1::Exceptions

    object :request, class: ActionDispatch::Request
    string :key, default: nil
    integer :page, default: 1
    integer :page_size, default: Address.default_per_page

    def execute
      address = Explore.run!(key:)
      raise AddressNotFoundError if address.is_a?(NullAddress)

      return LockHashSerializer.new(address[0]) if QueryKeyUtils.valid_hex?(key)

      options = FastJsonapi::PaginationMetaGenerator.new(
        request:, records: address, page:, page_size:, total_count: address.count,
      ).call
      AddressSerializer.new(address, options)
    end
  end
end
