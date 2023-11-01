module Api
  module V2
    module Portfolio
      class StatisticsController < BaseController
        before_action :validate_jwt!, :check_addresses_consistent!

        def index
          expires_in 30.minutes, public: true, stale_while_revalidate: 10.minutes, stale_if_error: 10.minutes

          addresses = current_user.addresses
          balance = addresses.pluck(:balance).sum
          balance_occupied = addresses.pluck(:balance_occupied).sum
          dao_deposit = addresses.pluck(:dao_deposit).sum
          interest = addresses.pluck(:interest).sum
          unclaimed_compensation = addresses.pluck(:unclaimed_compensation).sum

          json = {
            balance: balance.to_s,
            balance_occupied: balance_occupied.to_s,
            dao_deposit: dao_deposit.to_s,
            interest: interest.to_s,
            dao_compensation: (interest.to_i + unclaimed_compensation.to_i).to_s
          }

          render json: { data: json }
        end

        private

        def check_addresses_consistent!
          address = Address.find_by_address_hash(params[:latest_address])
          unless current_user.portfolios.exists?(address: address)
            latest_address = current_user.portfolios.last&.address
            raise Api::V2::Exceptions::PortfolioLatestDiscrepancyError.new(latest_address&.address_hash)
          end
        end
      end
    end
  end
end
