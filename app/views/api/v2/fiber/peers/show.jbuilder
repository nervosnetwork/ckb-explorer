json.data do
  json.(@peer, :peer_id, :rpc_listening_addr, :first_channel_opened_at, :last_channel_updated_at)
  json.fiber_channels @peer.fiber_channels do |peer_channel|
    json.peer_id peer_channel.peer_id
    json.channel_id peer_channel.channel_id
    json.state_name peer_channel.state_name
    json.state_flags peer_channel.state_flags
  end
end
