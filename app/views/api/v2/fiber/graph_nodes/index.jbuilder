json.data do
  json.fiber_graph_nodes @nodes do |node|
    json.(node, :alias, :node_id, :addresses, :timestamp, :chain_hash, :connected_node_ids, :open_channels_count)
    json.timestamp node.timestamp.to_s
    json.auto_accept_min_ckb_funding_amount node.auto_accept_min_ckb_funding_amount.to_s
    json.total_capacity node.total_capacity.to_s
    json.udt_cfg_infos node.udt_cfg_infos
    json.channel_links_count node.channel_links.count
  end
end
json.meta do
  json.total @nodes.total_count
  json.page_size @page_size.to_i
end
