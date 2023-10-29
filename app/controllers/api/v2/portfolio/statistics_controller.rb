module Api
  module V2
    module Portfolio
      class StatisticsController < BaseController
        before_action :validate_jwt!, :check_addresses_consistent!

        def index
          expires_in 30.minutes, public: true, stale_while_revalidate: 10.minutes, stale_if_error: 10.minutes
          @portfolio_statistic = current_user.portfolio_statistic
        end

        private

        def check_addresses_consistent!
          address = Address.find_by_address_hash(params[:address])
          unless current_user.portfolios.exists?(address: address)
            latest_address = current_user.portfolios.last&.address
            raise Api::V2::Exceptions::PortfolioLatestDiscrepancyError.new(latest_address&.address_hash)
          end
        end
      end
    end
  end
end
