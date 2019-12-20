module Api
  module V1
    module External
      class StatsController < ApplicationController
        skip_before_action :check_header_info

        def show
          return if params[:id] != "tip_block_number"

          render json: Block.recent.first&.number.to_s
        end
      end
    end
  end
end
