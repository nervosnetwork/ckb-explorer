module Api
  module V1
    class StatisticsController < ApplicationController
      def show
        ranking = MinerRanking.new
        render json: MinerRankingSerializer.new(ranking)
      end
    end
  end
end
