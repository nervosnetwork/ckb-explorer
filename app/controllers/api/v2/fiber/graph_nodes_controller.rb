module Api
  module V2
    module Fiber
      class GraphNodesController < BaseController
        def index
          @page = params.fetch(:page, 1)
          @page_size = params.fetch(:page_size, FiberGraphNode.default_per_page)
          @nodes =
            if params[:q].present?
              FiberGraphNode.where("node_name = :q or peer_id = :q or node_id = :q", q: params[:q]).page(@page).per(@page_size)
            else
              FiberGraphNode.all.page(@page).per(@page_size)
            end
        end

        def show
          @node = FiberGraphNode.find_by(node_id: params[:node_id])
          raise Api::V2::Exceptions::FiberGraphNodeNotFoundError unless @node

          @graph_channels = FiberGraphChannel.where(node1: params[:node_id]).or(
            FiberGraphChannel.where(node2: params[:node_id]),
          )

          if params[:status] == "closed"
            @graph_channels = @graph_channels.where.not(closed_transaction_id: nil)
          end
        end

        def addresses
          nodes = FiberGraphNode.all.select(:node_id, :addresses)
          render json: { data: nodes.map { _1.attributes.except("id") } }
        end
      end
    end
  end
end
