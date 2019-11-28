module Api
  module V1
    class MarketDataController < ApplicationController
      skip_before_action :check_header_info

      def show
        return if params[:id] != "circulating_supply"

        render json: MarketData.new.circulating_supply
      end
    end
  end
end
