json.data do
  json.fiber_graph_nodes @nodes do |node|
    json.(node, :node_name, :node_id, :addresses, :peer_id, :timestamp, :chain_hash, :connected_node_ids, :open_channels_count)
    json.timestamp node.timestamp.to_s
    json.auto_accept_min_ckb_funding_amount node.auto_accept_min_ckb_funding_amount.to_s
    json.total_capacity node.total_capacity.to_s
    json.udt_cfg_infos node.udt_cfg_infos
  end
end
json.meta do
  json.total @nodes.total_count
  json.page_size @page_size.to_i
end
