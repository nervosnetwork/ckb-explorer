class FiberChannelSerializer
  include FastJsonapi::ObjectSerializer

  attributes :peer_id, :channel_id, :state_name, :state_flags, :local_balance,
             :sent_tlc_balance, :remote_balance, :received_tlc_balance, :shutdown_at,
             :created_at, :updated_at
end
