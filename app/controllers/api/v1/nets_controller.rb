module Api
  module V1
    class NetsController < ApplicationController
      def index
        net_info = NetInfo.new
        render json: NetInfoSerializer.new(net_info, params: { info_name: "local_node_info" })
      end

      def show
        net_info = NetInfo.new
        render json: NetInfoSerializer.new(net_info, params: { info_name: params[:id] })
      end
    end
  end
end

