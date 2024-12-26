json.data do
  json.(@node, :alias, :node_id, :addresses, :peer_id, :timestamp, :chain_hash, :connected_node_ids)
  json.timestamp @node.timestamp.to_s
  json.auto_accept_min_ckb_funding_amount @node.auto_accept_min_ckb_funding_amount.to_s
  json.total_capacity @node.total_capacity.to_s
  json.udt_cfg_infos @node.udt_cfg_infos

  json.fiber_graph_channels @graph_channels do |channel|
    json.(channel, :channel_outpoint, :node1, :node2, :chain_hash, :open_transaction_info, :closed_transaction_info, :udt_info)
    json.funding_tx_block_number channel.funding_tx_block_number.to_s
    json.funding_tx_index channel.funding_tx_index.to_s
    json.last_updated_timestamp channel.last_updated_timestamp.to_s
    json.created_timestamp channel.created_timestamp.to_s
    json.node1_to_node2_fee_rate channel.node1_to_node2_fee_rate.to_s
    json.node2_to_node1_fee_rate channel.node2_to_node1_fee_rate.to_s
    json.capacity channel.capacity.to_s
  end
end
