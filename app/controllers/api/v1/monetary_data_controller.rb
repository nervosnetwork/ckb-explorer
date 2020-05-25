module Api
  module V1
    class MonetaryDataController < ApplicationController
      def show
        monetary_data = MonetaryData.new

        render json: MonetaryDataSerializer.new(monetary_data, params: { indicator: params[:id] })
      end
    end
  end
end
