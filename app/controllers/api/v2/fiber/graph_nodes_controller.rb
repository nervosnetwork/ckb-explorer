module Api
  module V2
    module Fiber
      class GraphNodesController < BaseController
        before_action :find_node, only: %i[show graph_channels transactions]

        def index
          @nodes = GraphNodes::Index.run!({ key: params[:q], page: params[:page], page_size: params[:page_size] })
        end

        def show; end

        def graph_channels
          @channels = GraphNodes::GraphChannels.run!(query_params)
        end

        def transactions
          @transactions = GraphNodes::Transactions.run!(query_params)
        end

        def addresses
          nodes = FiberGraphNode.all.select(:node_id, :addresses)
          render json: { data: nodes.map { { node_id: _1.node_id, addresses: _1.addresses, connections: _1.connected_node_ids } } }
        end

        private

        def find_node
          @node = FiberGraphNode.with_deleted.find_by(node_id: params[:node_id])
          raise Api::V2::Exceptions::FiberGraphNodeNotFoundError unless @node
        end

        def query_params
          params.permit(:node_id, :sort, :page, :page_size, :type_hash, :min_token_amount, :max_token_amount,
                        :address_hash, :status, :start_date, :end_date)
        end
      end
    end
  end
end
