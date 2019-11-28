module Api
  module V1
    class MarketDataController < ApplicationController
      def show
        return if params[:id] != "circulating_supply"

        render json: MarketData.new.circulating_supply
      end
    end
  end
end
