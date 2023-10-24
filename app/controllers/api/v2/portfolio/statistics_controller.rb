module Api
  module V2
    module Portfolio
      class StatisticsController < BaseController
        before_action :validate_jwt!, :check_addresses_consistent!

        def index
          @portfolio_statistic = current_user.portfolio_statistic
        end

        private

        def check_addresses_consistent!
          address = Address.find_by_address_hash(params[:address])
          unless current_user.portfolios.exists?(address: address)
            raise Api::V2::Exceptions::PortfolioLatestDiscrepancyError
          end
        end
      end
    end
  end
end
