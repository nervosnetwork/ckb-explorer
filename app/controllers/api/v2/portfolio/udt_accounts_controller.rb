module Api
  module V2
    module Portfolio
      class UdtAccountsController < BaseController
        before_action :validate_jwt!

        def index
          expires_in 30.minutes, public: true, stale_while_revalidate: 10.minutes, stale_if_error: 10.minutes

          statistic = Portfolios::UdtAccountsStatistic.new(current_user)
          if params[:cell_type] == "sudt"
            accounts = statistic.sudt_accounts(params[:published])
          else
            accounts = statistic.nft_accounts
          end

          render json: accounts
        end
      end
    end
  end
end
