module Api
  module V1
    class BlockStatisticsController < ApplicationController
      before_action :validate_query_params

      def show
        block_statistics = BlockStatistic.order(id: :desc).limit(1000).reverse
        render json: BlockStatisticSerializer.new(block_statistics, { params: { indicator: params[:id] } })
      end

      private

      def validate_query_params
        validator = Validations::BlockStatistic.new(params)

        if validator.invalid?
          errors = validator.error_object[:errors]
          status = validator.error_object[:status]

          render json: errors, status: status
        end
      end
    end
  end
end
