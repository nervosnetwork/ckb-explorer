module Api
  module V1
    class DistributionDataController < ApplicationController
      def show
        distribution_data = DistributionData.new
        render json: DistributionDataSerializer.new(distribution_data, { params: { indicator: params[:id] }})
      end
    end
  end
end
