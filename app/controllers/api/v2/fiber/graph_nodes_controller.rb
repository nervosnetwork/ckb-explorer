module Api
  module V2
    module Fiber
      class GraphNodesController < BaseController
        def index
          @page = params.fetch(:page, 1)
          @page_size = params.fetch(:page_size, FiberGraphNode.default_per_page)
          @nodes =
            if params[:q].present?
              FiberGraphNode.with_deleted.where("node_name = :q or peer_id = :q or node_id = :q", q: params[:q]).page(@page).per(@page_size)
            else
              FiberGraphNode.with_deleted.page(@page).per(@page_size)
            end
        end

        def show
          @node = FiberGraphNode.with_deleted.find_by(node_id: params[:node_id])
          raise Api::V2::Exceptions::FiberGraphNodeNotFoundError unless @node

          @graph_channels = FiberGraphChannel.with_deleted.where(node1: params[:node_id]).or(
            FiberGraphChannel.with_deleted.where(node2: params[:node_id]),
          )

          if params[:status] == "closed"
            @graph_channels = @graph_channels.with_deleted.where.not(closed_transaction_id: nil)
          end
        end

        def addresses
          nodes = FiberGraphNode.all.select(:node_id, :addresses)
          render json: { data: nodes.map { { node_id: _1.node_id, addresses: _1.addresses, connections: _1.connected_node_ids } } }
        end
      end
    end
  end
end
