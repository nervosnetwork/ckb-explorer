json.data do
  json.(@node, :node_name, :node_id, :addresses, :peer_id, :timestamp, :chain_hash, :connected_node_ids, :last_updated_timestamp,
        :deleted_at_timestamp, :created_timestamp)
  json.timestamp @node.timestamp.to_s
  json.auto_accept_min_ckb_funding_amount @node.auto_accept_min_ckb_funding_amount.to_s
  json.total_capacity @node.total_capacity.to_s
  json.udt_cfg_infos @node.udt_cfg_infos
end
