module Users
  class Statistics < ActiveInteraction::Base
    include Api::V2::Exceptions

    object :user
    string :latest_address

    validates :latest_address, presence: true
    validate :check_addresses_consistent!

    def execute
      addresses = user.addresses
      balance = addresses.pluck(:balance).sum
      balance_occupied = addresses.pluck(:balance_occupied).sum
      dao_deposit = addresses.pluck(:dao_deposit).sum
      interest = addresses.pluck(:interest).sum
      unclaimed_compensation = addresses.pluck(:unclaimed_compensation).sum
      dao_compensation = interest.to_i + unclaimed_compensation.to_i

      CkbUtils.hash_value_to_s(balance:, balance_occupied:, dao_deposit:,
                               interest:, dao_compensation:)
    end

    private

    def check_addresses_consistent!
      unless QueryKeyUtils.valid_address?(latest_address)
        raise AddressNotMatchEnvironmentError.new(ENV["CKB_NET_MODE"])
      end

      address = Address.find_by_address_hash(latest_address)
      unless user.portfolios.exists?(address:)
        address = user.portfolios.last&.address
        raise PortfolioLatestDiscrepancyError.new(address&.address_hash)
      end
    end
  end
end
