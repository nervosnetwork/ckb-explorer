module Api
  module V2
    module Fiber
      class ChannelsController < BaseController
        def show
          @channel = FiberChannel.find_by(channel_id: params[:channel_id])
          raise Api::V2::Exceptions::FiberChannelNotFoundError unless @channel
        end
      end
    end
  end
end
