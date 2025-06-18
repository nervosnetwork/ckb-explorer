json.data do
  json.fiber_graph_channels @channels do |channel|
    json.(channel, :channel_outpoint, :node1, :node2, :chain_hash, :open_transaction_info, :closed_transaction_info)
    json.last_updated_timestamp_of_node1 channel.last_updated_timestamp_of_node1.to_s
    json.last_updated_timestamp_of_node2 channel.last_updated_timestamp_of_node2.to_s
    json.created_timestamp channel.created_timestamp.to_s
    json.fee_rate_of_node1 channel.fee_rate_of_node1.to_s
    json.fee_rate_of_node2 channel.fee_rate_of_node2.to_s
    json.capacity channel.capacity.to_s
    json.udt_cfg_info channel.udt_info
  end
end
json.meta do
  json.total @channels.total_count
  json.page_size @channels.current_per_page
end
