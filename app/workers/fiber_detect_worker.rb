class FiberDetectWorker
  include Sidekiq::Worker
  sidekiq_options queue: "fiber"

  def perform(peer_id)
    fiber_peers = peer_id.present? ? FiberPeer.where(peer_id:) : FiberPeer.all
    fiber_peers.each { sync_with_fiber_channels(_1) }
  end

  private

  def sync_with_fiber_channels(fiber_peer)
    channels_attributes = build_channels_attributes(fiber_peer)
    FiberChannel.upsert_all(channels_attributes, unique_by: %i[peer_id channel_id])
  end

  def build_channels_attributes(fiber_peer)
    data = rpc.list_channels(fiber_peer.rpc_listening_addr, { peer_id: nil })
    data["result"]["channels"].map do |channel|
      {
        fiber_peer_id: fiber_peer.id,
        peer_id: channel["peer_id"],
        channel_id: channel["channel_id"],
        state_name: channel["state"]["state_name"],
        state_flags: parse_state_flags(channel["state"]["state_flags"]),
        local_balance: channel["local_balance"].to_i(16),
        offered_tlc_balance: channel["offered_tlc_balance"].to_i(16),
        remote_balance: channel["remote_balance"].to_i(16),
        received_tlc_balance: channel["received_tlc_balance"].to_i(16),
        created_at: Time.at(channel["created_at"].to_i(16) / 10**6),
      }
    end
  end

  def parse_state_flags(flags)
    case flags
    when Array
      flags
    when String
      flags.split("|")
    else
      []
    end
  end

  def rpc
    @rpc ||= FiberCoordinator.instance
  end
end
