module Api
  module V2
    module Fiber
      class GraphChannelsController < BaseController
        def index
          @page = params.fetch(:page, 1)
          @page_size = params.fetch(:page_size, FiberPeer.default_per_page)
          @channels = FiberGraphChannel.all
          if params[:status] == "closed"
            @channels = @channels.where.not(closed_transaction_id: nil)
          end
          @channels = @channels.page(@page).per(@page_size)
        end
      end
    end
  end
end
