module Api
  module V1
    class MarketDataController < ApplicationController
      skip_before_action :check_header_info

      def show
        render json: MarketData.new(indicator: params[:id]).call
      end
    end
  end
end
