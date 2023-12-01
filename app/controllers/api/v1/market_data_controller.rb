module Api
  module V1
    class MarketDataController < ApplicationController
      skip_before_action :check_header_info

      def index
        render json: MarketData.new.indicators_json
      end

      def show
        render json: MarketData.new(indicator: params[:id]).call
      end
    end
  end
end
