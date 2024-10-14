json.data do
  json.fiber_graph_channels @channels do |channel|
    json.(channel, :channel_outpoint, :node1, :node2, :chain_hash)
    json.funding_tx_block_number channel.funding_tx_block_number.to_s
    json.funding_tx_index channel.funding_tx_index.to_s
    json.last_updated_timestamp channel.last_updated_timestamp.to_s
    json.created_timestamp channel.created_timestamp.to_s
    json.node1_to_node2_fee_rate channel.node1_to_node2_fee_rate.to_s
    json.node2_to_node1_fee_rate channel.node2_to_node1_fee_rate.to_s
    json.capacity channel.capacity.to_s
  end
end
json.meta do
  json.total @channels.total_count
  json.page_size @page_size.to_i
end
