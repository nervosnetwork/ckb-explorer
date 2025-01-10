class FiberGraphNodeSerializer
  include FastJsonapi::ObjectSerializer

  attributes :id, :node_name, :node_id, :peer_id, :addresses, :timestamp, :chain_hash,
             :auto_accept_min_ckb_funding_amount
end
