json.data do
  json.fiber_peers @peers do |peer|
    json.(peer, :name, :peer_id, :rpc_listening_addr, :first_channel_opened_at,:last_channel_updated_at, :channels_count)
    json.total_local_balance peer.total_local_balance.to_s
  end
end
json.meta do
  json.total @peers.total_count
  json.page_size @page_size.to_i
end
