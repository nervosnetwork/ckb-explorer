module Api
  module V2
    module Portfolio
      class AddressesController < BaseController
        before_action :validate_jwt!

        def create
          address_hashes = params.fetch(:addresses, [])
          ::Portfolio.sync_addresses(current_user, address_hashes)

          head :no_content
        rescue StandardError => e
          raise Api::V2::Exceptions::SyncPortfolioAddressesError
        end
      end
    end
  end
end
