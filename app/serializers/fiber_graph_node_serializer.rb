class FiberGraphNodeSerializer
  include FastJsonapi::ObjectSerializer

  attributes :id, :alias, :node_id, :peer_id, :addresses, :timestamp, :chain_hash,
             :auto_accept_min_ckb_funding_amount
end
