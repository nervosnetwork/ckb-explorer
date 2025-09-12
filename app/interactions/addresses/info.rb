module Addresses
  class Info < ActiveInteraction::Base
    include Api::V1::Exceptions

    object :request, class: ActionDispatch::Request
    string :key, default: nil
    integer :page, default: 1
    integer :page_size, default: Address.default_per_page

    def execute
      result = find_address
      address = result ? wrap_result(result) : NullAddress.new(key)

      raise AddressNotFoundError if address.is_a?(NullAddress)

      return LockHashSerializer.new(address[0]) if QueryKeyUtils.valid_hex?(key)

      options = FastJsonapi::PaginationMetaGenerator.new(
        request:, records: address, page:, page_size:, total_count: address.count,
      ).call
      AddressSerializer.new(address, options)
    end

    private

    def find_address
      return Address.includes(udt_accounts: [:udt], lock_script: [], bitcoin_address: []).find_by(lock_hash: key) if QueryKeyUtils.valid_hex?(key)
      return find_by_address_hash(key) if QueryKeyUtils.valid_address?(key)

      find_by_bitcoin_address_hash(key) if BitcoinUtils.valid_address?(key)
    end

    def find_by_address_hash(key)
      lock_hash = CkbUtils.parse_address(key).script.compute_hash
      address = Address.includes(udt_accounts: [:udt], lock_script: [], bitcoin_address: []).find_by(lock_hash:)
      address.query_address = key if address
      address
    rescue StandardError
      nil
    end

    def find_by_bitcoin_address_hash(key)
      address_ids = BitcoinAddressMapping.includes(:bitcoin_address).
        where(bitcoin_address: { address_hash: key }).pluck(:ckb_address_id)
      Address.includes(udt_accounts: [:udt], lock_script: [], bitcoin_address: []).where(id: address_ids)
    end

    def wrap_result(result)
      result.is_a?(Address) ? [result] : result
    end
  end
end
