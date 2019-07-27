module Api
  module V1
    class NetsController < ApplicationController
      before_action :validate_query_params, only: :show

      def index
        net_info = NetInfo.new
        render json: NetInfoSerializer.new(net_info, params: { info_name: "local_node_info" })
      end

      def show
        net_info = NetInfo.new
        render json: NetInfoSerializer.new(net_info, params: { info_name: params[:id] })
      end

      private

      def validate_query_params
        validator = Validations::NetInfo.new(params)

        if validator.invalid?
          errors = validator.error_object[:errors]
          status = validator.error_object[:status]

          render json: errors, status: status
        end
      end
    end
  end
end

