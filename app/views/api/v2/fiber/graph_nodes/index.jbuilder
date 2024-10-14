json.data do
  json.fiber_graph_nodes @nodes do |node|
    json.(node, :alias, :node_id, :addresses, :timestamp, :chain_hash)
    json.timestamp node.timestamp.to_s
    json.auto_accept_min_ckb_funding_amount node.auto_accept_min_ckb_funding_amount.to_s
  end
end
json.meta do
  json.total @nodes.total_count
  json.page_size @page_size.to_i
end
