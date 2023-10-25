module Api
  module V2
    module Portfolio
      class AddressesController < BaseController
        before_action :validate_jwt!

        def create
          address_hashes = params.fetch(:addresses, [])
          address_hashes.each do |address_hash|
            address = Address.find_or_create_by_address_hash(address_hash)
            current_user.portfolios.find_or_create_by(address: address)
          end

          head :no_content
        rescue StandardError => e
          raise Api::V2::Exceptions::SyncPortfolioAddressesError
        end
      end
    end
  end
end
