module Api
  module V2
    module Portfolio
      class StatisticsController < BaseController
        before_action :validate_jwt!

        def index
          expires_in 30.minutes, public: true, stale_while_revalidate: 10.minutes, stale_if_error: 10.minutes
          data = Users::Statistics.run!({ user: current_user, latest_address: params[:latest_address] })
          render json: { data: }
        end
      end
    end
  end
end
