module Api
  module V2
    module Fiber
      class PeersController < BaseController
        before_action :test_connection, only: :create

        def index
          @peers = FiberPeer.all
        end

        def show
          @peer = FiberPeer.find_by(peer_id: params[:peer_id])
          raise Api::V2::Exceptions::FiberPeerNotFoundError unless @peer
        end

        def create
          fiber_peer = FiberPeer.find_or_initialize_by(peer_id: fiber_peer_params[:peer_id])
          fiber_peer.assign_attributes(fiber_peer_params)
          fiber_peer.save!

          FiberDetectWorker.perform_async(fiber_peer.peer_id)

          head :no_content
        rescue ActiveRecord::RecordInvalid => e
          raise Api::V2::Exceptions::FiberPeerParamsInvalidError.new(e.message)
        end

        private

        def fiber_peer_params
          params.permit(:name, :peer_id, :rpc_listening_addr)
        end

        def test_connection
          endpoint = fiber_peer_params[:rpc_listening_addr]
          payload = { "peer_id": fiber_peer_params[:peer_id] }
          FiberCoordinator.instance.list_channels(endpoint, payload)
        rescue ArgumentError => e
          raise Api::V2::Exceptions::FiberPeerParamsInvalidError.new(e.message)
        end
      end
    end
  end
end
