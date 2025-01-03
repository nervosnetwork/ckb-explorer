json.data do
  json.(@node, :alias, :node_id, :addresses, :peer_id, :timestamp, :chain_hash, :connected_node_ids)
  json.timestamp @node.timestamp.to_s
  json.auto_accept_min_ckb_funding_amount @node.auto_accept_min_ckb_funding_amount.to_s
  json.total_capacity @node.total_capacity.to_s
  json.udt_cfg_infos @node.udt_cfg_infos

  json.fiber_graph_channels @graph_channels do |channel|
    json.(channel, :channel_outpoint, :node1, :node2, :chain_hash, :open_transaction_info, :closed_transaction_info, :udt_info)
    json.last_updated_timestamp_of_node1 channel.last_updated_timestamp_of_node1.to_s
    json.last_updated_timestamp_of_node2 channel.last_updated_timestamp_of_node2.to_s
    json.fee_rate_of_node1 channel.fee_rate_of_node1.to_s
    json.fee_rate_of_node2 channel.fee_rate_of_node2.to_s
    json.created_timestamp channel.created_timestamp.to_s
    json.capacity channel.capacity.to_s
  end
end
