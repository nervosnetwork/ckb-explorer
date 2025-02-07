module Api
  module V1
    class MarketDataController < ApplicationController
      skip_before_action :check_header_info

      def index
        expires_in 30.minutes, public: true, stale_while_revalidate: 10.minutes, stale_if_error: 10.minutes
        render json: MarketData.new.indicators_json
      end

      def show
        expires_in 30.minutes, public: true, stale_while_revalidate: 10.minutes, stale_if_error: 10.minutes
        render json: MarketData.new(indicator: params[:id]).call
      end
    end
  end
end
