module Addresses
  class Explore < ActiveInteraction::Base
    string :key, default: nil

    def execute
      result = find_address
      result ? wrap_result(result) : NullAddress.new(key)
    end

    private

    def find_address
      return Address.find_by(lock_hash: key) if QueryKeyUtils.valid_hex?(key)
      return find_by_address_hash(key) if QueryKeyUtils.valid_address?(key)
      return find_by_bitcoin_address_hash(key) if BitcoinUtils.valid_address?(key)
    end

    def find_by_address_hash(key)
      lock_hash = CkbUtils.parse_address(key).script.compute_hash
      address = Address.find_by(lock_hash:)
      address.query_address = key if address
      address
    rescue StandardError
      nil
    end

    def find_by_bitcoin_address_hash(key)
      address_ids = BitcoinAddressMapping.includes(:bitcoin_address).
        where(bitcoin_address: { address_hash: key }).pluck(:address_id)
      Address.where(id: address_ids)
    end

    def wrap_result(result)
      result.is_a?(Array) ? result : [result]
    end
  end
end
